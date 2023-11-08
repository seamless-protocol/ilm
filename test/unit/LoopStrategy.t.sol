// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IAaveOracle } from
    "@aave/contracts/interfaces/IAaveOracle.sol";
import { IPoolConfigurator } from "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import { BaseForkTest } from "../BaseForkTest.t.sol";
import { LendingPool, LoanState, StrategyAssets, CollateralRatio } from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { IPausable } from "../../src/interfaces/IPausable.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";

/// @notice Setup for the tests for the LoopStrategy contract
contract LoopStrategyTest is BaseForkTest {
    using stdStorage for StdStorage;

    IPoolAddressesProvider public constant poolAddressProvider =
        IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);
    IPoolDataProvider public poolDataProvider;
    IPriceOracleGetter public priceOracle;
    ISwapper public swapper;
    StrategyAssets public strategyAssets;
    CollateralRatio public collateralRatioTargets;
    LendingPool public lendingPool;

    LoopStrategy public strategy;

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    WrappedCbETH public wrappedCbETH;

    uint256 swapOffset;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        lendingPool = LendingPool({
            pool: IPool(poolAddressProvider.getPool()),
            // variable interest rate mode is 2
            interestRateMode: 2
        });

        // deploy MockAaveOracle to the address of already existing priceOracle
        MockAaveOracle mockOracle = new MockAaveOracle();
        bytes memory mockOracleCode = address(mockOracle).code;
        vm.etch(poolAddressProvider.getPriceOracle(), mockOracleCode);
        priceOracle = IPriceOracleGetter(poolAddressProvider.getPriceOracle());

        _changePrice(USDbC, 1e8);
        _changePrice(CbETH, 2000 * 1e8);

        wrappedCbETH =
            new WrappedCbETH("wCbETH", "wCbETH", CbETH, address(this));

        swapper =
        new SwapperMock(address(CbETH), address(USDbC), address(priceOracle));
        strategyAssets = StrategyAssets({
            underlying: CbETH,
            collateral: CbETH,
            debt: USDbC
        });

        collateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 100),
            minForRebalance: USDWadRayMath.usdDiv(180, 100),
            maxForRebalance: USDWadRayMath.usdDiv(220, 100),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 100),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 100)
        });

        strategy = new LoopStrategy();
        strategy.LoopStrategy_init(
            address(this),
            strategyAssets,
            collateralRatioTargets,
            poolAddressProvider,
            priceOracle,
            swapper,
            10**4, // 0.01% ratio margin
            10
        );

        wrappedCbETH.setDepositPermission(address(strategy), true);

        // fake minting some tokens to start with
        deal(address(CbETH), address(this), 100 ether);

        SwapperMock(address(swapper)).setOffsets(5e5, 5e5);
        swapOffset = swapper.offsetFactor(
            strategyAssets.debt, strategyAssets.collateral
        );

        _changeBorrowCap(USDbC, 1000000);
    }

    /// @dev test confirms that functions reverts when pool is paused
    function test_pausableFunctions_revertEnforcedPause() public {
        IPausable(address(strategy)).pause();

        vm.expectRevert(abi.encodeWithSelector(IPausable.EnforcedPause.selector));
        strategy.deposit(1 ether, address(this));
        vm.expectRevert(abi.encodeWithSelector(IPausable.EnforcedPause.selector));
        strategy.withdraw(1 ether, address(this), address(this));
        vm.expectRevert(abi.encodeWithSelector(IPausable.EnforcedPause.selector));
        strategy.redeem(1 ether, address(this), address(this));
    }

    /// @dev test confimrs that mint function is disabled
    function test_mint_revertMintDisabled() public {
        vm.expectRevert(abi.encodeWithSelector(ILoopStrategy.MintDisabled.selector));
        strategy.mint(1 ether, address(this));
        assertEq(strategy.previewMint(1 ether), 0);
    }

    /// @dev test confirms that changing asset price on the price oracle works
    function test_changePrice() public {
        _changePrice(CbETH, 1234 * 1e8);
        assertEq(priceOracle.getAssetPrice(address(CbETH)), 1234 * 1e8);
    }

    function _depositFor(address user, uint256 amount)
        internal
        returns (uint256 shares)
    {
        vm.startPrank(user);
        deal(address(strategyAssets.underlying), user, amount);
        strategyAssets.underlying.approve(address(strategy), amount);
        shares = strategy.deposit(amount, user);
        vm.stopPrank();
    }

    function _depositFor(address user, uint256 amount, uint256 minSharesReceived) internal returns(uint256 shares) {
        vm.startPrank(user);
        deal(address(strategyAssets.underlying), user, amount);
        strategyAssets.underlying.approve(address(strategy), amount);
        shares = strategy.deposit(amount, user, minSharesReceived);
        vm.stopPrank();
    }

    function _changePrice(IERC20 token, uint256 price) internal {
        MockAaveOracle(address(priceOracle)).setAssetPrice(
            address(token), price
        );
    }

    /// @dev changes the borrow cap parameter for the given asset
    /// @param asset asset to change borrow cap
    /// @param borrowCap new borrow cap amount (in the whole token amount of asset - i.e. no decimals)
    function _changeBorrowCap(IERC20 asset, uint256 borrowCap) internal {
      address aclAdmin = poolAddressProvider.getACLAdmin();
      vm.startPrank(aclAdmin);
      IPoolConfigurator(poolAddressProvider.getPoolConfigurator()).setBorrowCap(address(asset), borrowCap);
      vm.stopPrank();
    }

}
