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
import { RewardsDepositor } from "./helpers/RewardsDepositor.sol";

import "forge-std/console.sol";

contract LoopStrategyDepositTest is LoopStrategyTest {
    address public constant SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS =
        0x639d2dD24304aC2e6A691d8c1cFf4a2665925fee;
    IRewardsController public constant REWARDS_CONTROLLER =
        IRewardsController(0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780);
    IPoolConfigurator public constant POOL_CONFIGURATOR =
        IPoolConfigurator(0x7B08A77539A50218c8fB4B706B87fb799d3505A0);
    IAaveOracle public constant AAVE_ORACLE =
        IAaveOracle(0xFDd4e83890BCcd1fbF9b10d71a5cc0a738753b01);
    IPool public constant POOL =
        IPool(0x8F44Fd754285aa6A2b8B9B97739B79746e0475a7);

    MockERC20 public supplyToken = new MockERC20("Supply Token", "ST");
    MockERC20 public rewardToken = new MockERC20("Reward Token", "RT");
    MockAaveOracle public oracle;
    MockTransferStrategy public transferStrategy;

    RewardsDepositor public rewardsDepositor;

    function setUp() public override {
        super.setUp();

        _openLendingPoolMarket();

        oracle = new MockAaveOracle();
        oracle.setAssetPrice(address(strategy), 1e8);
        transferStrategy = new MockTransferStrategy();
        excludeContract(address(transferStrategy));

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
            asset: _getSTokenAddress(address(supplyToken)),
            reward: address(rewardToken),
            transferStrategy: ITransferStrategyBase(address(transferStrategy)),
            rewardOracle: IEACAggregatorProxy(address(oracle))
        });
        REWARDS_CONTROLLER.configureAssets(config);

        rewardsDepositor = new RewardsDepositor(
            address(strategy),
            address(POOL),
            address(REWARDS_CONTROLLER),
            address(rewardToken),
            address(supplyToken)
        );

        vm.stopPrank();

        vm.allowCheatcodes(address(rewardsDepositor));
        rewardsDepositor.createUsers();

        excludeContract(address(strategy));
        excludeContract(address(oracle));
        excludeContract(address(transferStrategy));
        excludeContract(address(swapper));
        excludeContract(address(supplyToken));
        excludeContract(address(rewardToken));
        excludeContract(address(rewardsDepositor));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = rewardsDepositor.deposit.selector;
        selectors[1] = rewardsDepositor.withdraw.selector;
        selectors[2] = rewardsDepositor.transfer.selector;

        FuzzSelector memory selector = FuzzSelector({
            addr: address(rewardsDepositor),
            selectors: selectors
        });

        targetSelector(selector);
    }

    function test_Deposit_OneUser() public {
        uint256 depositAmount = 1 ether;
        uint256 sharesReturned = _depositFor(alice, depositAmount);

        uint256 timeToPass = 1 days;
        uint256 totalDistributedRewards = timeToPass * 1 ether;
        vm.warp(block.timestamp + timeToPass);

        address[] memory assets = new address[](1);
        assets[0] = address(strategy);
        uint256 userRewards = REWARDS_CONTROLLER.getUserRewards(
            assets, alice, address(rewardToken)
        );

        assertApproxEqAbs(userRewards, totalDistributedRewards, 1);
    }

    function test_Rewards_MultipleActions() public {
        uint256 depositAmount = 1 ether;
        _depositFor(alice, depositAmount);
        _validateRewards();

        uint256 timeToPass = 1 days;
        vm.warp(block.timestamp + timeToPass);
        _validateRewards();

        depositAmount = 3 ether;
        _depositFor(bob, depositAmount);
        _validateRewards();

        timeToPass = 998;
        _transfer(bob, alice, 0.3 ether);
        _validateRewards();

        timeToPass = 2 days;
        vm.warp(block.timestamp + timeToPass);
        _validateRewards();

        depositAmount = 2 ether;
        _depositFor(charlie, depositAmount);
        _validateRewards();

        timeToPass = 0;
        vm.warp(block.timestamp + timeToPass);
        _validateRewards();

        timeToPass = 99823418;
        _transfer(alice, bob, 0.1 ether);
        _validateRewards();

        uint256 redeemAmount = 0.4 ether;
        _redeemFrom(bob, redeemAmount);
        _validateRewards();

        timeToPass = 1 days;
        vm.warp(block.timestamp + timeToPass);
        _validateRewards();

        redeemAmount = 0.6 ether;
        _redeemFrom(alice, redeemAmount);
        _validateRewards();

        timeToPass = 123491234;
        _transfer(charlie, bob, 0.15 ether);
        _validateRewards();
    }

    function invariant_MultipleActions() public {
        address[] memory users = rewardsDepositor.getActors();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            assertEq(
                _getUserRewards(address(strategy), user),
                _getUserRewards(_getSTokenAddress(address(supplyToken)), user)
            );
        }
    }

    function _getSTokenAddress(address reserve) internal returns (address) {
        DataTypes.ReserveData memory reserveData = POOL.getReserveData(reserve);
        return reserveData.aTokenAddress;
    }

    function _getUserRewards(address asset, address user)
        internal
        view
        returns (uint256)
    {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        return REWARDS_CONTROLLER.getUserRewards(
            assets, user, address(rewardToken)
        );
    }

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
        address sSupplyTokenAddress = _getSTokenAddress(address(supplyToken));

        vm.startPrank(from);
        IERC20(sSupplyTokenAddress).transfer(to, amount);
        strategy.transfer(to, amount);
        vm.stopPrank();
    }

    function _validateRewards() internal {
        address sSupplyTokenAddress = _getSTokenAddress(address(supplyToken));

        assertEq(
            _getUserRewards(address(strategy), alice),
            _getUserRewards(sSupplyTokenAddress, alice)
        );

        assertEq(
            _getUserRewards(address(strategy), bob),
            _getUserRewards(sSupplyTokenAddress, bob)
        );

        assertEq(
            _getUserRewards(address(strategy), charlie),
            _getUserRewards(sSupplyTokenAddress, charlie)
        );
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
            aTokenImpl: 0x27076A995387458da63b23d9AFe3df851727A8dB,
            stableDebtTokenImpl: 0xb4D5e163738682A955404737f88FDCF15C1391bF,
            variableDebtTokenImpl: 0x3800DA378e17A5B8D07D0144c321163591475977,
            underlyingAssetDecimals: 18,
            interestRateStrategyAddress: 0x0FFc5886D69cc3c432ed421515C2A3B831dB9210,
            underlyingAsset: address(supplyToken),
            treasury: 0x982F3A0e3183896f9970b8A9Ea6B69Cd53AF1089,
            incentivesController: 0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780,
            aTokenName: "Token name",
            aTokenSymbol: "Symbol",
            variableDebtTokenName: "Token name",
            variableDebtTokenSymbol: "Symbol",
            stableDebtTokenName: "Token name",
            stableDebtTokenSymbol: "Symbol",
            params: new bytes(0x1)
        });

        POOL_CONFIGURATOR.initReserves(reserveConfig);
        POOL_CONFIGURATOR.setSupplyCap(address(supplyToken), 68719476735);
        AAVE_ORACLE.setAssetSources(assets, sources);

        vm.stopPrank();
    }
}
