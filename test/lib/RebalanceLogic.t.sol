// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

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

    //address public SUPPLIER = address(123123123);
    /// @dev sets up testing context
    function setUp() public virtual override {
        super.setUp();

        LoanLogic.supply(
            $.lendingPool, $.assets.collateral, (MINT_AMOUNT / 1000)
        );

        targetCR = $.collateralRatioTargets.target;
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
    /// when rebalancing requires a single iteration with a zero withdrawal value
    function test_rebalanceDown_bringsCollateralRatioToTarget_RequiringOneIteration_ZeroValueWithdrawal(
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

        ratio = RebalanceLogic.rebalanceDown($, state, 0, currentCR, targetCR);

        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// when rebalancing requires a single iteration with a non zero withdrawal value
    function test_rebalanceDown_bringsCollateralRatioToTarget_RequiringOneIteration_NonZeroValueWithdrawal(
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

        uint256 withdrawalUSD = 1000 * USDWadRayMath.USD; // 1000 USD

        ratio = RebalanceLogic.rebalanceDown(
            $, state, withdrawalUSD, currentCR, targetCR
        );

        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// when rebalancing requires multiple iterations with a zero withdrawal value
    function test_rebalanceDown_bringsCollateralRatioToTarget_RequiringMultipleIterations_ZeroValueWithdrawal(
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

        ratio = RebalanceLogic.rebalanceDown($, state, 0, currentCR, targetCR);

        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    /// when rebalancing requires multiple iterations with a non zero withdrawal value
    function test_rebalanceDown_bringsCollateralRatioToTarget_RequiringMultipleIterations_NonZeroValueWithdrawal(
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

        uint256 withdrawalUSD = 1000 * USDWadRayMath.USD; // 1000 USD

        ratio = RebalanceLogic.rebalanceDown(
            $, state, withdrawalUSD, currentCR, targetCR
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

        ratio = RebalanceLogic.rebalanceDown($, state, 0, currentCR, targetCR);

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

    /// @dev ensures that calculating the collateral ratio gives the expected value, for a range
    /// of inputs
    /// @param _collateralUSD fuzzed value of collateral held by contract in USD
    /// @param _debtUSD fuzzed value of debt held by contract in USD
    function testFuzz_collateralRatioUSD(
        uint256 _collateralUSD,
        uint256 _debtUSD
    ) public {
        _debtUSD = bound(
            _debtUSD, 0, (type(uint256).max - _debtUSD / 2) / USDWadRayMath.USD
        );
        /// assume that collateral is always larger than debt because otherwise
        /// position would have been liquidated
        _collateralUSD = bound(
            _collateralUSD,
            _debtUSD,
            (type(uint256).max - _debtUSD / 2) / USDWadRayMath.USD
        );

        uint256 ratio;

        if (_debtUSD == 0) {
            ratio = RebalanceMath.collateralRatioUSD(_collateralUSD, _debtUSD);
            assertEq(ratio, type(uint256).max);
        } else {
            ratio = RebalanceMath.collateralRatioUSD(_collateralUSD, _debtUSD);
            assertEq(ratio, _collateralUSD.usdDiv(_debtUSD));
        }
    }

    /// @dev ensures that converting assets amounts to USD amounts results in the expected value,
    /// for a range of inputs
    /// @param _assetAmount fuzzed amount of asset to convert in USD
    /// @param _priceInUSD fuzzed price of asset in USD
    /// @param _assetDecimals fuzzed value of asset decimals
    function testFuzz_convertAssetToUSD(
        uint256 _assetAmount,
        uint256 _priceInUSD,
        uint256 _assetDecimals
    ) public {
        // prevent overflows
        _assetDecimals = bound(_assetDecimals, 0, 18); // assume tokens with no more than 18 decimals would be used as assets
        _priceInUSD = bound(_priceInUSD, 0, 1 ** 12);
        _assetAmount = bound(_assetAmount, 0, 5 * 10 ** 60);

        uint256 _usdAmount = ConversionMath.convertAssetToUSD(
            _assetAmount, _priceInUSD, _assetDecimals
        );

        assertEq(
            _usdAmount, _assetAmount * _priceInUSD / (10 ** _assetDecimals)
        );
    }

    /// @dev ensures that converting USD amounts to asset amounts results in the expected value,
    /// for a range of inputs
    /// @param _usdAmount fuzzed amount of USD to convert to asset
    /// @param _priceInUSD fuzzed price of asset in USD
    /// @param _assetDecimals fuzzed value of asset decimals
    function testFuzz_convertUSDtoAsset(
        uint256 _usdAmount,
        uint256 _priceInUSD,
        uint256 _assetDecimals
    ) public {
        vm.assume(_assetDecimals <= 18 && _assetDecimals != 0); // assume no tokens with more than 18 decimals would be used as assets
        vm.assume(_priceInUSD <= 250_000 * 10 ** 8 && _priceInUSD != 0); // assume no token has a price larger than 250000 USD
        vm.assume(_usdAmount <= 5 * 10 ** 60 && _usdAmount != 0); // assume no astronomical value of USD to be converted

        uint256 _assetAmount = ConversionMath.convertUSDToAsset(
            _usdAmount, _priceInUSD, _assetDecimals
        );

        uint8 USD_DECIMALS = 8;

        if (USD_DECIMALS > _assetDecimals) {
            assertEq(
                _assetAmount,
                _usdAmount.usdDiv(_priceInUSD)
                    / 10 ** (USD_DECIMALS - _assetDecimals)
            );
        } else {
            assertEq(
                _assetAmount,
                _usdAmount.usdDiv(_priceInUSD)
                    * 10 ** (_assetDecimals - USD_DECIMALS)
            );
        }
    }

    /// @dev ensures that offsetting a USD value down results in the expected value,
    /// for a range of inputs
    /// @param _a fuzzed value to offset down
    /// @param _offsetUSD fuzzed value of _offsetUSD
    function testFuzz__offset_USDAmountDown(uint256 _a, uint256 _offsetUSD)
        public
    {
        _offsetUSD = bound(_offsetUSD, 0, USDWadRayMath.USD - 1);

        uint256 amount = RebalanceMath.offsetUSDAmountDown(_a, _offsetUSD);

        // ensure overflows are accounted for
        if (_a <= type(uint256).max / (USDWadRayMath.USD - _offsetUSD)) {
            assertEq(
                amount,
                (_a * (USDWadRayMath.USD - _offsetUSD) / USDWadRayMath.USD)
            );
        } else {
            assertEq(
                amount,
                (_a / USDWadRayMath.USD) * (USDWadRayMath.USD - _offsetUSD)
            );
        }
    }

    /// @dev ensures that requiredBorrowUSD returns the value required to reach target CR
    /// @param _ltv fuzzed value of loan-to-value ratio
    /// @param _targetCR fuzzed value of collateral ratio target
    /// @param __collateralUSD fuzzed value of collateral in USD
    /// @param __debtUSD fuzzed value of debt in USD
    /// @param _offsetFactor fuzzed value of offset (from 0 - 1 USD)
    function testFuzz_requiredBorrowUSD(
        uint256 _ltv,
        uint256 _targetCR,
        uint256 __collateralUSD,
        uint256 __debtUSD,
        uint256 _offsetFactor
    ) public {
        /// need a minimum LTV and maximum LTV to bound all other variables
        /// LTV must always be < 1 as we are working with overcallateralized positions
        _ltv = bound(_ltv, 0.01e8, 0.9e8);
        /// offsetFactor is a value up to 1e8
        _offsetFactor = bound(_offsetFactor, 0, 1e8);
        /// target CR must be at least 1 / LTV
        /// max bound is set to be very high because at that point it is as if we have 0 debt (debt is neglible)
        _targetCR = bound(_targetCR, (USDWadRayMath.USD).usdDiv(_ltv), 1e26);

        /// assume less than 3 trillion USD collateral, and more than 1 USD
        __collateralUSD = bound(__collateralUSD, 1e8, 3e20);

        __debtUSD = bound(__debtUSD, 0, __collateralUSD.usdMul(_ltv));

        if (__collateralUSD > _targetCR.usdMul(__debtUSD)) {
            uint256 requiredBorrow = RebalanceMath.requiredBorrowUSD(
                _targetCR, __collateralUSD, __debtUSD, _offsetFactor
            );

            uint256 actualBorrow = (
                __collateralUSD - _targetCR.usdMul(__debtUSD)
            ).usdDiv(_targetCR - (USDWadRayMath.USD - _offsetFactor));

            assertEq(requiredBorrow, actualBorrow);
        }
    }
}
