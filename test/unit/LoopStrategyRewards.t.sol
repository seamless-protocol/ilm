// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { LoopStrategyTest } from "./LoopStrategy.t.sol";
import { IRewardsController } from
    "@aave-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import { RewardsDataTypes } from
    "@aave-periphery/contracts/rewards/libraries/RewardsDataTypes.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { MockTransferStrategy } from "../mock/MockTransferStrategy.sol";
import { ITransferStrategyBase } from
    "@aave-periphery/contracts/rewards/interfaces/ITransferStrategyBase.sol";
import { IEACAggregatorProxy } from
    "@aave-periphery/contracts/misc/interfaces/IEACAggregatorProxy.sol";
import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { ConfiguratorInputTypes } from
    "@aave/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { DataTypes } from
    "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import { RewardsHandler } from "./helpers/RewardsHandler.sol";
import "forge-std/console.sol";

contract LoopStrategyDepositTest is LoopStrategyTest {
    MockERC20 public supplyToken = new MockERC20("Supply Token", "ST");
    MockERC20 public rewardToken = new MockERC20("Reward Token", "RT");
    MockAaveOracle public oracle;
    MockTransferStrategy public transferStrategy;

    address public sSupplyTokenAddress;
    RewardsHandler public rewardsDepositor;

    function setUp() public override {
        super.setUp();

        _openLendingPoolMarket();

        oracle = new MockAaveOracle();
        oracle.setAssetPrice(address(strategy), 1e8);

        transferStrategy = new MockTransferStrategy();

        address emissionManager = REWARDS_CONTROLLER.getEmissionManager();

        vm.startPrank(emissionManager);

        RewardsDataTypes.RewardsConfigInput[] memory config =
            new RewardsDataTypes.RewardsConfigInput[](2);

        config[0] = RewardsDataTypes.RewardsConfigInput({
            emissionPerSecond: 1 ether,
            totalSupply: 0,
            distributionEnd: type(uint32).max,
            asset: address(strategy),
            reward: address(rewardToken),
            transferStrategy: ITransferStrategyBase(address(transferStrategy)),
            rewardOracle: IEACAggregatorProxy(address(oracle))
        });
        config[1] = RewardsDataTypes.RewardsConfigInput({
            emissionPerSecond: 1 ether,
            totalSupply: 0,
            distributionEnd: type(uint32).max,
            asset: sSupplyTokenAddress,
            reward: address(rewardToken),
            transferStrategy: ITransferStrategyBase(address(transferStrategy)),
            rewardOracle: IEACAggregatorProxy(address(oracle))
        });
        REWARDS_CONTROLLER.configureAssets(config);

        rewardsDepositor = new RewardsHandler(
            address(strategy),
            address(POOL),
            address(REWARDS_CONTROLLER),
            address(rewardToken),
            address(supplyToken)
        );

        vm.stopPrank();

        vm.allowCheatcodes(address(rewardsDepositor));
        rewardsDepositor.createUsers();

        // This is necessary so all deployed contracts in setUp are removed from the target contracts list
        targetContract(address(rewardsDepositor));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = rewardsDepositor.deposit.selector;
        selectors[1] = rewardsDepositor.withdraw.selector;
        selectors[2] = rewardsDepositor.transfer.selector;
        selectors[3] = rewardsDepositor.claimAllRewards.selector;

        FuzzSelector memory selector = FuzzSelector({
            addr: address(rewardsDepositor),
            selectors: selectors
        });

        targetSelector(selector);
    }

    function test_Deposit_OneUser() public {
        uint256 depositAmount = 3 ether;
        _depositFor(alice, depositAmount);

        uint256 timeToPass = 1 days;
        uint256 totalDistributedRewards = timeToPass * 1 ether;
        vm.warp(block.timestamp + timeToPass);

        address[] memory assets = new address[](1);
        assets[0] = address(strategy);
        uint256 userRewards = REWARDS_CONTROLLER.getUserRewards(
            assets, alice, address(rewardToken)
        );

        assertEq(userRewards, totalDistributedRewards - 1);
    }

    function invariant_MultipleActions() public { }

    function _depositFor(address user, uint256 amount)
        internal
        override
        returns (uint256)
    {
        uint256 shares = super._depositFor(user, amount);

        deal(address(supplyToken), user, amount);

        vm.startPrank(user);
        supplyToken.approve(address(POOL), shares);
        POOL.supply(address(supplyToken), shares, user, 0);
        vm.stopPrank();

        return shares;
    }

    function _redeemFrom(address user, uint256 amount) internal {
        vm.startPrank(user);

        strategy.redeem(amount, user, user);
        POOL.withdraw(address(supplyToken), amount, user);

        vm.stopPrank();
    }

    function _transfer(address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        IERC20(sSupplyTokenAddress).transfer(to, amount);
        strategy.transfer(to, amount);
        vm.stopPrank();
    }

    function _openLendingPoolMarket() internal {
        vm.startPrank(SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS);

        address[] memory assets = new address[](1);
        assets[0] = address(supplyToken);

        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        ConfiguratorInputTypes.InitReserveInput[] memory reserveConfig =
            new ConfiguratorInputTypes.InitReserveInput[](1);
        reserveConfig[0] = ConfiguratorInputTypes.InitReserveInput({
            aTokenImpl: SEAMLESS_ATOKEN_IMPL,
            stableDebtTokenImpl: SEAMLESS_STABLE_DEBT_TOKEN_IMPL,
            variableDebtTokenImpl: SEAMLESS_VARIABLE_DEBT_TOKEN_IMPL,
            underlyingAssetDecimals: 18,
            interestRateStrategyAddress: SEAMLESS_CBETH_INTEREST_RATE_STRATEGY_ADDRESS,
            underlyingAsset: address(supplyToken),
            treasury: SEAMLESS_TREASURY,
            incentivesController: SEAMLESS_INCENTIVES_CONTROLLER,
            aTokenName: "Token name",
            aTokenSymbol: "Symbol",
            variableDebtTokenName: "Token name",
            variableDebtTokenSymbol: "Symbol",
            stableDebtTokenName: "Token name",
            stableDebtTokenSymbol: "Symbol",
            params: new bytes(0x1)
        });

        POOL_CONFIGURATOR.initReserves(reserveConfig);
        POOL_CONFIGURATOR.setSupplyCap(address(supplyToken), MAX_SUPPLY_CAP);
        AAVE_ORACLE.setAssetSources(assets, sources);

        DataTypes.ReserveData memory reserveData =
            POOL.getReserveData(address(supplyToken));
        sSupplyTokenAddress = reserveData.aTokenAddress;

        vm.stopPrank();
    }
}
