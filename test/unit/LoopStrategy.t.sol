// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IAccessControl } from
    "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import { SwapAdapterMock } from "../mock/SwapAdapterMock.t.sol";
import { BaseForkTest } from "../BaseForkTest.t.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio,
    Step
} from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { IPausable } from "../../src/interfaces/IPausable.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoopStrategyStorage as Storage } from
    "../../src/storage/LoopStrategyStorage.sol";
import { Swapper } from "../../src/swap/Swapper.sol";
import { WrappedERC20PermissionedDeposit } from
    "../../src/tokens/WrappedERC20PermissionedDeposit.sol";

/// @notice Setup for the tests for the LoopStrategy contract
contract LoopStrategyTest is BaseForkTest {
    using stdStorage for StdStorage;

    /////////////////////////////
    ///// REPLICATED EVENTS /////
    /////////////////////////////

    // @notice emitted when a new value for maxIterations is set
    /// @param iterations new value for maxIterations
    event MaxIterationsSet(uint16 iterations);

    /// @notice emitted when a new value for ratioMargin is set
    /// @param margin new value for ratioMargin
    event RatioMarginSet(uint256 margin);

    /// @notice emitted when a new value for usdMargin is set
    /// @param margin new value for usdMargin
    event USDMarginSet(uint256 margin);

    /// @notice emitted when a new value for the swapper address is set
    /// @param swapper new address of swapper contract
    event SwapperSet(address swapper);

    /// @notice emitted when a new value for the collateralRatioTargets is set
    /// @param targets new value of collateralRatioTargest struct
    event CollateralRatioTargetsSet(CollateralRatio targets);

    IPoolAddressesProvider public constant poolAddressProvider =
        IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);
    IPoolDataProvider public poolDataProvider;
    IPriceOracleGetter public priceOracle;
    ISwapper public swapper;
    StrategyAssets public strategyAssets;
    CollateralRatio public collateralRatioTargets;

    LoopStrategy public strategy;

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    WrappedERC20PermissionedDeposit public wrappedToken;

    SwapAdapterMock wethCbETHAdapter;

    uint256 COLLATERAL_PRICE = 2000 * 1e8;
    uint256 DEBT_PRICE = 1e8;

    uint256 OFFSET_DEVIATION_USD = 1e6; // 1% at 1e8
    uint256 swapOffset;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address NO_ROLE = makeAddr("norole");

    function setUp() public virtual {
        poolDataProvider =
            IPoolDataProvider(poolAddressProvider.getPoolDataProvider());

        // deploy MockAaveOracle to the address of already existing priceOracle
        MockAaveOracle mockOracle = new MockAaveOracle();
        bytes memory mockOracleCode = address(mockOracle).code;
        vm.etch(poolAddressProvider.getPriceOracle(), mockOracleCode);
        priceOracle = IPriceOracleGetter(poolAddressProvider.getPriceOracle());

        _changePrice(USDbC, DEBT_PRICE);
        _changePrice(CbETH, COLLATERAL_PRICE);
        _changePrice(WETH, COLLATERAL_PRICE * 80 / 100);

        wrappedToken = new WrappedERC20PermissionedDeposit(
            "wCbETH", "wCbETH", CbETH, address(this)
        );

        swapper = new SwapperMock(
            address(CbETH), address(USDbC), address(priceOracle)
        );
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

        LoopStrategy strategyImplementation = new LoopStrategy();

        ERC1967Proxy strategyProxy = new ERC1967Proxy(
            address(strategyImplementation),
            abi.encodeWithSelector(
                LoopStrategy.LoopStrategy_init.selector,
                "ILM_NAME",
                "ILM_SYMBOL",
                address(this),
                strategyAssets,
                collateralRatioTargets,
                poolAddressProvider,
                priceOracle,
                swapper,
                10 ** 4, // 0.01% ratio margin
                10
            )
        );
        strategy = LoopStrategy(address(strategyProxy));

        strategy.grantRole(strategy.PAUSER_ROLE(), address(this));
        strategy.grantRole(strategy.MANAGER_ROLE(), address(this));
        strategy.grantRole(strategy.UPGRADER_ROLE(), address(this));

        wrappedToken.grantRole(wrappedToken.DEPOSITOR_ROLE(), address(strategy));

        // fake minting some tokens to start with
        deal(address(CbETH), address(this), 100 ether);

        // set both offsets to be the same value
        SwapperMock(address(swapper)).setRealOffsets(5e5, 5e5);
        SwapperMock(address(swapper)).setOffsets(5e5, 5e5);

        swapOffset =
            swapper.offsetFactor(strategyAssets.debt, strategyAssets.collateral);

        _changeSupplyAndBorrowCap(USDbC, 30_000_000_000, 10_000_000_000);
        _changeSupplyAndBorrowCap(WETH, 30_000_000_000, 10_000_000_000);
        _changeSupplyAndBorrowCap(CbETH, 30_000_000_000, 10_000_000_000);
    }

    /// @dev mints user new underlying token assets, approves and calls deposit function on the strategy
    /// @param user user for which deposit is called
    /// @param amount amount of minted and deposited assets
    function _depositFor(address user, uint256 amount)
        internal
        virtual
        returns (uint256 shares)
    {
        vm.startPrank(user);
        deal(address(strategyAssets.underlying), user, amount);
        strategyAssets.underlying.approve(address(strategy), amount);
        shares = strategy.deposit(amount, user);
        vm.stopPrank();
    }

    /// @dev mints user new underlying token assets, approves and calls deposit function on the strategy
    /// with the given minSharesReceived parameter
    /// @param user user for which deposit is called
    /// @param amount amount of minted and deposited assets
    /// @param minSharesReceived minimum shares expected to be recived on calling deposit
    function _depositFor(
        address user,
        uint256 amount,
        uint256 minSharesReceived
    ) internal returns (uint256 shares) {
        vm.startPrank(user);
        deal(address(strategyAssets.underlying), user, amount);
        strategyAssets.underlying.approve(address(strategy), amount);
        shares = strategy.deposit(amount, user, minSharesReceived);
        vm.stopPrank();
    }

    /// @dev mints user new underlying token assets, approves and calls deposit function with the expected revert
    /// @param user user for which deposit is called
    /// @param amount amount of minted and deposited assets
    /// @param revertReason encoded error which is expected to be reverted on deposit call
    function _depositForExpectsRevert(
        address user,
        uint256 amount,
        bytes memory revertReason
    ) internal returns (uint256 shares) {
        vm.startPrank(user);
        deal(address(strategyAssets.underlying), user, amount);
        strategyAssets.underlying.approve(address(strategy), amount);
        vm.expectRevert(revertReason);
        shares = strategy.deposit(amount, user);
        vm.stopPrank();
    }

    /// @dev changes price on the mock oracle for the given token
    /// @param token token which price is changed
    /// @param price new price which is set
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
        IPoolConfigurator(poolAddressProvider.getPoolConfigurator())
            .setBorrowCap(address(asset), borrowCap);
        vm.stopPrank();
    }

    /// @dev changes the borrow and cap parameter for the given asset
    /// @param asset asset to change borrow cap
    /// @param supplyCap new supply cap amount (in the whole token amount of asset - i.e. no decimals)
    /// @param borrowCap new borrow cap amount (in the whole token amount of asset - i.e. no decimals)
    function _changeSupplyAndBorrowCap(
        IERC20 asset,
        uint256 supplyCap,
        uint256 borrowCap
    ) internal {
        address aclAdmin = poolAddressProvider.getACLAdmin();
        vm.startPrank(aclAdmin);
        IPoolConfigurator(poolAddressProvider.getPoolConfigurator())
            .setSupplyCap(address(asset), supplyCap);
        IPoolConfigurator(poolAddressProvider.getPoolConfigurator())
            .setBorrowCap(address(asset), borrowCap);
        vm.stopPrank();
    }

    /// @dev changes the ltv and liquidation parameters for the given asset
    /// @param asset asset to change ltv and liquidation parameters
    /// @param ltv new ltv (from 0 to 100_00 in percents)
    /// @param liquidationThreshold new liquidation treshold (from 0 to 100_00 in percents)
    /// @param liquidationBonus new liquidation bonus (in percents, should be above 100_00)
    function _changeLtv(
        IERC20 asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) internal {
        address aclAdmin = poolAddressProvider.getACLAdmin();
        vm.startPrank(aclAdmin);
        IPoolConfigurator(poolAddressProvider.getPoolConfigurator())
            .configureReserveAsCollateral(
            address(asset), ltv, liquidationThreshold, liquidationBonus
        );
        vm.stopPrank();
    }

    /// @dev sets up a `Swapper` implementation with a single mock adapter
    function _setupSwapperWithMockAdapter() internal {
        // deploy one mock swap adapter
        wethCbETHAdapter = new SwapAdapterMock();

        // deploy and initiliaze swapper
        Swapper swapperImplementation = new Swapper();
        ERC1967Proxy swapperProxy = new ERC1967Proxy(
            address(swapperImplementation),
            abi.encodeWithSelector(
                Swapper.Swapper_init.selector,
                address(this),
                priceOracle,
                OFFSET_DEVIATION_USD
            )
        );

        strategy.setSwapper(address(swapperProxy));

        Swapper(address(swapperProxy)).grantRole(
            Swapper(address(swapperProxy)).MANAGER_ROLE(), address(this)
        );
        Swapper(address(swapperProxy)).grantRole(
            Swapper(address(swapperProxy)).UPGRADER_ROLE(), address(this)
        );
        Swapper(address(swapperProxy)).grantRole(
            Swapper(address(swapperProxy)).STRATEGY_ROLE(), address(this)
        );
        Swapper(address(swapperProxy)).grantRole(
            Swapper(address(swapperProxy)).STRATEGY_ROLE(), address(strategy)
        );

        Step[] memory steps = new Step[](1);
        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });
        Swapper(address(swapperProxy)).setRoute(WETH, CbETH, steps);

        Step[] memory stepsTwo = new Step[](1);
        stepsTwo[0] = Step({ from: CbETH, to: WETH, adapter: wethCbETHAdapter });
        Swapper(address(swapperProxy)).setRoute(CbETH, WETH, stepsTwo);

        // manually set debt asset to be WETH
        uint256 assetsDebtStorageSlot = uint256(Storage.STORAGE_SLOT) + 2;

        vm.store(
            address(strategy),
            bytes32(assetsDebtStorageSlot),
            bytes32(uint256(uint160(address(WETH))))
        );
    }
}
