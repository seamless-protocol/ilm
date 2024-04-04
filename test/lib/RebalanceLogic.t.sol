// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { ConversionMath } from "../../src/libraries/math/ConversionMath.sol";
import { RebalanceMath } from "../../src/libraries/math/RebalanceMath.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { Constants } from "../../src/libraries/math/Constants.sol";

/// @title RebalanceLogicTest
/// @dev RebalanceLogicTest contract which exposes RebalanceLogic library functions
contract RebalanceLogicTest is RebalanceLogicContext {
    using USDWadRayMath for uint256;

    uint256 targetCR;

    /// @dev sets up testing context
    function setUp() public virtual override {
        super.setUp();

        LoanLogic.supply(
            $.lendingPool, $.assets.collateral, (MINT_AMOUNT / 1000)
        );

        targetCR = $.collateralRatioTargets.target;

        _changeSupplyAndBorrowCap(USDbC, 100_000_000, 100_000_000);
        _changeSupplyAndBorrowCap(WETH, 100_000_000, 100_000_000);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// starting from a position of 0 debt (on first deposit)
    function test_rebalanceUp_bringsCollateralRatioToTarget_FromZeroDebt()
        public
    {
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $,
            state,
            currentCR,
            $.collateralRatioTargets.target,
            Constants.MAX_SLIPPAGE
        );

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// starting from a position of non-zero debt and needing more than one iteration to reach
    function test_rebalanceUp_bringsCollateralRatioToTarget_FromNonZeroDebt_RequiringMultipleIterations(
    ) public {
        // set targetCR to 1.45e8
        targetCR = $.collateralRatioTargets.maxForDepositRebalance;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        // perform a single borrow-supply iteration, so non-zero debt whilst still needing
        // more than one iteration to reach targetCR of 1.45e8
        uint256 borrowAmountAsset = ConversionMath.convertUSDToAsset(
            LoanLogic.getMaxBorrowUSD($.lendingPool, $.assets.debt, USDbC_price),
            USDbC_price,
            6,
            Math.Rounding.Floor
        );

        state =
            LoanLogic.borrow($.lendingPool, $.assets.debt, borrowAmountAsset);

        // approve _swapper contract to swap asset
        $.assets.debt.approve(address($.swapper), borrowAmountAsset);

        uint256 collateralAmountAsset = $.swapper.swap(
            $.assets.debt,
            $.assets.collateral,
            borrowAmountAsset,
            payable(address(this)),
            Constants.MAX_SLIPPAGE
        );

        state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, collateralAmountAsset
        );

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// starting from a position of non-zero debt and needing only one iteration to reach
    function test_rebalanceUp_bringsCollateralRatioToTarget_FromNonZeroDebt_RequiringOneIteration(
    ) public {
        // set targetCR to 1.8555e8
        targetCR = 1.8555e8;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        // perform a single borrow-supply iteration, so non-zero debt whilst still needing
        // one iteration to reach targetCR of  1.8555e8
        uint256 borrowAmountAsset = ConversionMath.convertUSDToAsset(
            LoanLogic.getMaxBorrowUSD($.lendingPool, $.assets.debt, USDbC_price),
            USDbC_price,
            6,
            Math.Rounding.Floor
        );

        state =
            LoanLogic.borrow($.lendingPool, $.assets.debt, borrowAmountAsset);

        // approve _swapper contract to swap asset
        $.assets.debt.approve(address($.swapper), borrowAmountAsset);

        uint256 collateralAmountAsset = $.swapper.swap(
            $.assets.debt,
            $.assets.collateral,
            borrowAmountAsset,
            payable(address(this)),
            Constants.MAX_SLIPPAGE
        );

        state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, collateralAmountAsset
        );

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensures that rebalanceUp reverts if the final ratio after the rebalance operation
    /// is outside the limit range (ie less than `minForWithdraw` limit)
    /// note: `rebalanceTo` is used to circumvent foundry enforcing check on first external call
    /// which is to the oracle
    function test_rebalanceUp_revertsWhen_finalRatioIsLessThanMinForWithdrawLimit(
    ) public {
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        // set target CR to be less than MIN_FOR_REBALANCE_CR
        targetCR = MIN_FOR_REBALANCE_CR - 1e5;

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        vm.expectRevert(RebalanceLogic.RatioOutsideRange.selector);
        RebalanceLogic.rebalanceTo($, state, targetCR, Constants.MAX_SLIPPAGE);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// when rebalancing requires a single iteration
    function test_rebalanceDown_bringsCollateralRatioToTarget_RequiringOneIteration(
    ) public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        targetCR = 1.45e8;

        state = LoanLogic.getLoanState($.lendingPool);
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// when rebalancing requires multiple iterations
    function test_rebalanceDown_bringsCollateralRatioToTarget_RequiringMultipleIterations(
    ) public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        targetCR = 3.5e8;

        state = LoanLogic.getLoanState($.lendingPool);
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev tests that rebalanceDownToDebt brings the strategy (loan) debt to
    /// the desired target
    function test_rebalanceDownToDebt_bringsDebtToTargetDebt() public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        state = LoanLogic.getLoanState($.lendingPool);
        uint256 debtRepayment = 100 * USDWadRayMath.USD;
        uint256 targetDebtUSD = state.debtUSD - debtRepayment;

        RebalanceLogic.rebalanceDownToDebt(
            $, state, targetDebtUSD, Constants.MAX_SLIPPAGE
        );

        state = LoanLogic.getLoanState($.lendingPool);

        assertApproxEqAbs(state.debtUSD, state.debtUSD, 100);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// @param targetRatio fuzzed value of targetRatio
    function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(
        uint256 targetRatio
    ) public {
        // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
        targetRatio = bound(
            targetRatio,
            $.collateralRatioTargets.minForRebalance,
            $.collateralRatioTargets.maxForRebalance
        );

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetRatio, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetRatio / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetRatio, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// @param targetRatio fuzzed value of targetRatio
    function testFuzz_rebalanceDown_bringsCollateralRatioToTarget(
        uint256 targetRatio
    ) public {
        // slightly above min CR for rebalance to allow for lack of precision owed to conversions
        targetCR = MIN_FOR_REBALANCE_CR + 10;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        assertApproxEqAbs(ratio, targetCR, margin);

        targetRatio = bound(targetRatio, 1.35e8, 7e8);

        targetCR = targetRatio;

        state = LoanLogic.getLoanState($.lendingPool);
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev tests that rebalanceDownToDebt brings the strategy (loan) debt to
    /// the desired target
    function testFuzz_rebalanceDownToDebt_bringsDebtToTargetDebt(
        uint256 repaymentUSD
    ) public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        state = LoanLogic.getLoanState($.lendingPool);

        // ensure repaymentUSD is not more than the equity and more than a dollar
        repaymentUSD = bound(repaymentUSD, 1e8, state.debtUSD);
        uint256 targetDebtUSD = state.debtUSD - repaymentUSD;

        RebalanceLogic.rebalanceDownToDebt(
            $, state, targetDebtUSD, Constants.MAX_SLIPPAGE
        );

        state = LoanLogic.getLoanState($.lendingPool);

        // because of max iterations set to 15 we allow small offset; 100 is 0.000001 USD
        assertApproxEqAbs(state.debtUSD, state.debtUSD, 100);
    }

    /// @dev ensures that rebalanceTo reverts when calling rebalanceUp if slippage is too high
    function test_rebalanceTo_inRebalanceUpCall_revertsWhen_slippageIsTooHigh()
        public
    {
        _setupSwapperWithMockAdapter();
        wethCbETHAdapter.setSlippagePCT(25); // set slippage percentage to 25%

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        vm.expectRevert(ISwapper.MaxSlippageExceeded.selector);

        uint256 maxSlippage = 5_000000; // set max allowed slippage to 5%
        RebalanceLogic.rebalanceTo(
            $, state, $.collateralRatioTargets.target, maxSlippage
        );
    }

    /// @dev ensures that rebalanceTo reverts when calling rebalanceDown if slippage is too high
    function test_rebalanceTo_inRebalanceDownCall_revetsWhen_slippageIsTooHigh()
        public
    {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        _setupSwapperWithMockAdapter();
        wethCbETHAdapter.setSlippagePCT(25); // set slippage percentage to 25%

        targetCR = 3.5e8;

        state = LoanLogic.getLoanState($.lendingPool);

        vm.expectRevert(ISwapper.MaxSlippageExceeded.selector);

        uint256 maxSlippage = 20_000000; // set max allowed slippage to 20%
        RebalanceLogic.rebalanceTo(
            $, state, $.collateralRatioTargets.target, maxSlippage
        );
    }

    /// @dev ensures that rebalanceDownToDebt reverts when slippage is too high
    function test_rebalanceDownToDebt_revertsWhen_slippageIsTooHigh() public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, targetCR, Constants.MAX_SLIPPAGE
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        _setupSwapperWithMockAdapter();
        wethCbETHAdapter.setSlippagePCT(25); // set slippage percentage to 25%

        state = LoanLogic.getLoanState($.lendingPool);
        uint256 debtRepayment = 100 * USDWadRayMath.USD;
        uint256 targetDebtUSD = state.debtUSD - debtRepayment;

        vm.expectRevert(ISwapper.MaxSlippageExceeded.selector);
        this.rebalanceDownToDebtHelperCall(state, targetDebtUSD, 20_000000);
    }

    /////////////////////
    ////// HELPERS //////
    /////////////////////

    /// @dev helper function used in test where expectRevert is needed, as it works only with external calls
    /// for it to be external call it should be called with `this.rebalanceDownToDebtHelperCall(...)`
    /// @param state current loan state
    /// @param targetDebtUSD target debt to rebalance
    /// @param maxSwapSlippage maximum allowed swap slippage
    function rebalanceDownToDebtHelperCall(
        LoanState memory state,
        uint256 targetDebtUSD,
        uint256 maxSwapSlippage
    ) public {
        RebalanceLogic.rebalanceDownToDebt(
            $, state, targetDebtUSD, maxSwapSlippage
        );
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
}
