// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { ConversionMath } from "../../src/libraries/math/ConversionMath.sol";
import { RebalanceMath } from "../../src/libraries/math/RebalanceMath.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

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
            $, state, currentCR, $.collateralRatioTargets.target
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
            6
        );

        state =
            LoanLogic.borrow($.lendingPool, $.assets.debt, borrowAmountAsset);

        // approve _swapper contract to swap asset
        $.assets.debt.approve(address($.swapper), borrowAmountAsset);

        uint256 collateralAmountAsset = $.swapper.swap(
            $.assets.debt,
            $.assets.collateral,
            borrowAmountAsset,
            payable(address(this))
        );

        state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, collateralAmountAsset
        );

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

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
            6
        );

        state =
            LoanLogic.borrow($.lendingPool, $.assets.debt, borrowAmountAsset);

        // approve _swapper contract to swap asset
        $.assets.debt.approve(address($.swapper), borrowAmountAsset);

        uint256 collateralAmountAsset = $.swapper.swap(
            $.assets.debt,
            $.assets.collateral,
            borrowAmountAsset,
            payable(address(this))
        );

        state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, collateralAmountAsset
        );

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        assertApproxEqAbs(ratio, targetCR, margin);
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

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        targetCR = 1.45e8;

        state = LoanLogic.getLoanState($.lendingPool);
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown($, state, currentCR, targetCR);

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

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        targetCR = 3.5e8;

        state = LoanLogic.getLoanState($.lendingPool);
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown($, state, currentCR, targetCR);

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

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        state = LoanLogic.getLoanState($.lendingPool);
        uint256 debtRepayment = 100 * USDWadRayMath.USD;
        uint256 targetDebtUSD = state.debtUSD - debtRepayment;

        RebalanceLogic.rebalanceDownToDebt($, state, targetDebtUSD);

        state = LoanLogic.getLoanState($.lendingPool);

        uint256 usdMargin = $.usdMargin * targetDebtUSD / USDWadRayMath.USD;

        assertApproxEqAbs(state.debtUSD, targetDebtUSD, usdMargin);
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

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetRatio);

        uint256 margin = $.ratioMargin * targetRatio / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetRatio, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// @param targetRatio fuzzed value of targetRatio
    function testFuzz_rebalanceDown_bringsCollateralRatioToTarget_ZeroValueWithdrawal(
        uint256 targetRatio
    ) public {
        // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
        targetCR = 1.34e8;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        assertApproxEqAbs(ratio, targetCR, margin);

        targetRatio = bound(targetRatio, 1.35e8, 7e8);

        targetCR = targetRatio;

        state = LoanLogic.getLoanState($.lendingPool);
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown($, state, currentCR, targetCR);

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

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);

        state = LoanLogic.getLoanState($.lendingPool);
        // ensure repaymentUSD is not more than the equity and more than a dollar
        repaymentUSD = bound(repaymentUSD, 1e8, state.debtUSD);
        uint256 targetDebtUSD = state.debtUSD - repaymentUSD;

        RebalanceLogic.rebalanceDownToDebt($, state, targetDebtUSD);

        state = LoanLogic.getLoanState($.lendingPool);

        uint256 usdMargin = $.usdMargin * targetDebtUSD / USDWadRayMath.USD;

        // force the margin to be about 1 dollar
        if (usdMargin == 0) {
            usdMargin = 1e8;
        }

        assertApproxEqAbs(state.debtUSD, targetDebtUSD, usdMargin);
    }

    /////////////////////
    ////// HELPERS //////
    /////////////////////

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
