// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import { SwapAdapterMock } from "../mock/SwapAdapterMock.t.sol";
import { LoopStrategyStorage as Storage } from
    "../../src/storage/LoopStrategyStorage.sol";
import { Swapper } from "../../src/swap/Swapper.sol";
import {
    CollateralRatio,
    LendingPool,
    LoanState,
    StrategyAssets,
    Step
} from "../../src/types/DataTypes.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";

/// @title RebalanceLogicContext contract
/// @dev Setup for the context in which the RebalanceLogic library is tested.
abstract contract RebalanceLogicContext is BaseForkTest {
    /// contracts needed for setting up and testing RebalanceLogic
    IPoolAddressesProvider public constant poolAddressProvider =
        IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);

    SwapAdapterMock wethCbETHAdapter;

    Storage.Layout $;

    /// values required for setting up and testing RebalanceLogic
    uint256 public WETH_price;
    uint256 public USDbC_price;
    uint256 public CbETH_price;

    uint256 internal constant BASIS = 1e8;
    uint256 internal constant MINT_AMOUNT = 1000 ether;
    CollateralRatio internal ratio;

    // set up ratios:
    // targerCR is 1.5e8 for 3x weighting, and the min/max values for rebalance are
    // determined by the maximum number of iterations (15 iterations can only allow to reach a certain target)
    uint256 internal constant TARGET_CR = 1.5e8;
    uint256 internal constant MIN_FOR_REBALANCE_CR = 134_444_444;
    uint256 internal constant MAX_FOR_REBALANCE_CR = 166_666_666;
    uint256 internal constant MIN_FOR_WITHDRAW_REBALANCE_CR = 1.55e8;
    uint256 internal constant MAX_FOR_DEPOSIT_REBALANCE_CR = 1.45e8;

    uint256 internal constant OFFSET_DEVIATION_USD = 1e6; // 1% at 1e8

    /// @dev sets up auxiliary contracts and context for RebalanceLogic tests
    function setUp() public virtual {
        // set up LoopStrategyStorage
        $.assets.collateral = WETH;
        $.assets.debt = USDbC;
        $.lendingPool = LendingPool({
            pool: IPool(poolAddressProvider.getPool()),
            // variable interest rate mode is 2
            interestRateMode: 2,
            sTokenCollateral: LoanLogic.getSToken(
                poolAddressProvider, $.assets.collateral
                )
        });
        $.oracle = IPriceOracleGetter(poolAddressProvider.getPriceOracle());
        $.ratioMargin = 100_000; // 1e2 / 1e8 = 0.001%
        $.collateralRatioTargets = CollateralRatio({
            target: TARGET_CR,
            minForRebalance: MIN_FOR_REBALANCE_CR,
            maxForRebalance: MAX_FOR_REBALANCE_CR,
            maxForDepositRebalance: MIN_FOR_WITHDRAW_REBALANCE_CR,
            minForWithdrawRebalance: MAX_FOR_DEPOSIT_REBALANCE_CR
        });
        $.maxIterations = 15;

        // getting token prices
        WETH_price = $.oracle.getAssetPrice(address(WETH));
        USDbC_price = $.oracle.getAssetPrice(address(USDbC));
        CbETH_price = $.oracle.getAssetPrice(address(CbETH));

        // deploy mock swapper instance
        $.swapper = new SwapperMock(
            address($.assets.collateral),
            address($.assets.debt),
            address($.oracle)
        );

        assert(
            address(SwapperMock(address($.swapper)).borrowAsset())
                == address(USDbC)
        );
        assert(
            address(SwapperMock(address($.swapper)).collateralAsset())
                == address(WETH)
        );

        // fake minting some tokens to start with
        deal(address(WETH), address(this), MINT_AMOUNT);
        deal(address(USDbC), address(this), MINT_AMOUNT);

        // approve tokens for pool to use on supplying and repaying
        WETH.approve(poolAddressProvider.getPool(), MINT_AMOUNT);
        USDbC.approve(poolAddressProvider.getPool(), MINT_AMOUNT);
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
                $.oracle,
                OFFSET_DEVIATION_USD
            )
        );

        $.swapper = Swapper(address(swapperProxy));

        Swapper(address($.swapper)).grantRole(
            Swapper(address($.swapper)).MANAGER_ROLE(), address(this)
        );
        Swapper(address($.swapper)).grantRole(
            Swapper(address($.swapper)).UPGRADER_ROLE(), address(this)
        );
        Swapper(address($.swapper)).grantRole(
            Swapper(address($.swapper)).STRATEGY_ROLE(), address(this)
        );

        Step[] memory steps = new Step[](1);
        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        Swapper(address($.swapper)).setRoute(WETH, CbETH, steps);

        $.assets.collateral = WETH;
        $.assets.debt = CbETH;
    }
}
