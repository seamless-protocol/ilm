// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

/// TODO: add natspec for fuzz tests

/// @title RebalanceLogicHarness
/// @dev RebalanceLogicHarness contract which exposes RebalanceLogic library functions
contract RebalanceLogicHarness is RebalanceLogicContext {
    using USDWadRayMath for uint256;

    //address public SUPPLIER = address(123123123);
    /// @dev sets up testing context
    function setUp() public virtual override {
        super.setUp();

        LoanLogic.supply(lendingPool, assets.collateral, (MINT_AMOUNT / 1000));
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// starting from a position of 0 debt (on first deposit)
    function test_rebalanceUp_bringsCollateralRatioToTarget_FromZeroDebt()
        public
    {
        LoanState memory state = LoanLogic.getLoanState(lendingPool);

        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio = RebalanceLogic.rebalanceUp(
            $, state, currentCR, $.collateralRatioTargets.target
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100_000);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// starting from a position of non-zero debt and needing more than one iteration to reach
    function test_rebalanceUp_bringsCollateralRatioToTarget_FromNonZeroDebt_RequiringMoreThanOneIteration(
    ) public {
        // set targetCR to 1.45e8
        targetCR = $.collateralRatioTargets.maxForDepositRebalance;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        LoanState memory state = LoanLogic.getLoanState(lendingPool);

        // perform a single borrow-supply iteration, so non-zero debt whilst still needing
        // more than one iteration to reach targetCR of 1.45e8
        uint256 borrowAmountAsset = RebalanceLogic.convertUSDToAsset(
            state.maxBorrowAmount, USDbC_price, 6
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

        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    /// starting from a position of non-zero debt and needing only one iteration to reach
    function test_rebalanceUp_bringsCollateralRatioToTarget_FromNonZeroDebt_RequiringOnlyOneIteration(
    ) public {
        // set targetCR to 1.8555e8
        targetCR = 1.8555e8;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        LoanState memory state = LoanLogic.getLoanState(lendingPool);

        // perform a single borrow-supply iteration, so non-zero debt whilst still needing
        // one iteration to reach targetCR of  1.8555e8
        uint256 borrowAmountAsset = RebalanceLogic.convertUSDToAsset(
            state.maxBorrowAmount, USDbC_price, 6
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

        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    function test_rebalanceDown_bringsCollateralRatioToTarget() public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        assertApproxEqAbs(ratio, targetCR, targetCR / 100_000);

        targetCR = 3.5e8;

        state = LoanLogic.getLoanState(lendingPool);
        currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        ratio = RebalanceLogic.rebalanceDown(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100_000);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(
        uint256 targetRatio
    ) public {
        // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
        targetRatio = bound(
            targetRatio,
            $.collateralRatioTargets.minForRebalance,
            $.collateralRatioTargets.maxForRebalance
        );

        uint256 targetCR = targetRatio;
        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(ratio, targetCR, margin);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    function testFuzz_rebalanceDown_bringsCollateralRatioToTarget(
        uint256 targetRatio
    ) public {
        // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
        targetCR = 1.34e8;

        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio =
            RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        assertApproxEqAbs(ratio, targetCR, targetCR / 100_000);

        targetRatio = bound(targetRatio, 1.35e8, 5e8);

        targetCR = targetRatio;

        state = LoanLogic.getLoanState(lendingPool);
        currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        ratio = RebalanceLogic.rebalanceDown(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100_000);
    }

    /// @dev ensures that calculating the collateral ratio gives the expected value, for a range
    /// of inputs
    function testFuzz_collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
        public
    {
        /// assume that collateral is always larger than debt because otherwise
        /// position would have been liquidated
        vm.assume(collateralUSD > debtUSD);

        uint256 ratio;

        if (debtUSD == 0) {
            ratio = RebalanceLogic.collateralRatioUSD(collateralUSD, debtUSD);
            assertEq(ratio, 0);
        } else if (
            collateralUSD
                <= (type(uint256).max - debtUSD / 2) / USDWadRayMath.USD
                && debtUSD != 0
        ) {
            ratio = RebalanceLogic.collateralRatioUSD(collateralUSD, debtUSD);
            assertEq(ratio, collateralUSD.usdDiv(debtUSD));
        } else {
            vm.expectRevert();
            ratio = RebalanceLogic.collateralRatioUSD(collateralUSD, debtUSD);
        }
    }

    /// @dev ensures that converting assets amounts to USD amounts results in the expected value,
    /// for a range of inputs
    function testFuzz_convertAssetToUSD(
        uint256 assetAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) public {
        vm.assume(assetDecimals <= 18); // assume no tokens with more than 18 decimals would be used as assets
        vm.assume(priceInUSD <= 250_000 * 10 ** 8); // assume no token has a price larger than 250000 USD
        vm.assume(assetAmount <= 5 * 10 ** 60); // assume no astronomical value of assets will need to be converted

        uint256 usdAmount = RebalanceLogic.convertAssetToUSD(
            assetAmount, priceInUSD, assetDecimals
        );

        assertEq(usdAmount, assetAmount * priceInUSD / (10 ** assetDecimals));
    }

    /// @dev ensures that converting USD amounts to asset amounts results in the expected value,
    /// for a range of inputs
    function testFuzz_convertUSDtoAsset(
        uint256 usdAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) public {
        vm.assume(assetDecimals <= 18 && assetDecimals != 0); // assume no tokens with more than 18 decimals would be used as assets
        vm.assume(priceInUSD <= 250_000 * 10 ** 8 && priceInUSD != 0); // assume no token has a price larger than 250000 USD
        vm.assume(usdAmount <= 5 * 10 ** 60 && usdAmount != 0); // assume no astronomical value of USD to be converted

        uint256 assetAmount = RebalanceLogic.convertUSDToAsset(
            usdAmount, priceInUSD, assetDecimals
        );

        uint8 USD_DECIMALS = 8;

        if (USD_DECIMALS > assetDecimals) {
            assertEq(
                assetAmount,
                usdAmount.usdDiv(priceInUSD)
                    / 10 ** (USD_DECIMALS - assetDecimals)
            );
        } else {
            assertEq(
                assetAmount,
                usdAmount.usdDiv(priceInUSD)
                    * 10 ** (assetDecimals - USD_DECIMALS)
            );
        }
    }

    /// @dev ensures that offsetting a USD value down results in the expected value,
    /// for a range of inputs
    function testFuzz_offsetUSDAmountDown(uint256 a, uint256 usdOffset)
        public
    {
        vm.assume(usdOffset <= USDWadRayMath.USD);
        vm.assume(usdOffset != USDWadRayMath.USD);

        uint256 amount = RebalanceLogic.offsetUSDAmountDown(a, usdOffset);

        // ensure overflows are accounted for
        if (a <= type(uint256).max / (USDWadRayMath.USD - usdOffset)) {
            assertEq(
                amount,
                (a * (USDWadRayMath.USD - usdOffset) / USDWadRayMath.USD)
            );
        } else {
            assertEq(
                amount,
                (a / USDWadRayMath.USD) * (USDWadRayMath.USD - usdOffset)
            );
        }
    }

    /// @dev ensures that requiredBorrowUSD returns the value required to reach target CR
    function testFuzz_requiredBorrowUSD(
        uint256 _ltv,
        uint256 _targetCR,
        uint256 _collateralUSD,
        uint256 _debtUSD,
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
        _collateralUSD = bound(_collateralUSD, 1e8, 3e20);

        _debtUSD = bound(_debtUSD, 0, _collateralUSD.usdMul(_ltv));

        if (_collateralUSD > _targetCR.usdMul(_debtUSD)) {
            uint256 requiredBorrow = RebalanceLogic.requiredBorrowUSD(
                _targetCR, _collateralUSD, _debtUSD, _offsetFactor
            );

            /// TODO: change this after MOCK
            uint256 actualBorrow = (_collateralUSD - _targetCR.usdMul(_debtUSD))
                .usdDiv(_targetCR - (USDWadRayMath.USD - _offsetFactor));

            assertEq(requiredBorrow, actualBorrow);
        }
    }

    // /// @dev ensures that requiredBorrowUSD returns the value required to reach target CR
    // function testFuzz_requiredBorrowUSD(
    //     uint256 _ltv,
    //     uint256 _targetCR,
    //     uint256 _collateralUSD,
    //     uint256 _debtUSD,
    //     uint256 _offsetFactor
    // ) public {
    //     /// need a minimum LTV and maximum LTV to bound all other variables
    //     /// LTV must always be < 1 as we are working with overcallateralized positions
    //     _ltv = bound(_ltv, 0.01e8, 0.9e8);
    //     /// offsetFactor is a value up to 1e8
    //     _offsetFactor = bound(_offsetFactor, 0, 1e8);
    //     /// target CR must be at least 1 / LTV,
    //     _targetCR =
    //         bound(_targetCR, (USDWadRayMath.USD).usdDiv(_ltv), type(uint256).max / 1e36);

    //     /// assume collateral < type(uint256).max / 1e18
    //     _collateralUSD =
    //         bound(_collateralUSD, 0, type(uint256).max / USDWadRayMath.WAD);
    //     /// enforce collateral > debt * CR since the maximum debt = C * LTV
    //     _debtUSD = bound(_debtUSD, 0, _collateralUSD.usdMul(_ltv));
    //      _targetCR = bound(_targetCR, 0, (type(uint256).max - USDWadRayMath.HALF_USD) / _debtUSD);
    //     /// enforce collateral > _targetCR.usdMul(_debtUSD) to prevent underflows
    //     _collateralUSD =
    //         bound(_collateralUSD, _targetCR.usdMul(_debtUSD), type(uint256).max / USDWadRayMath.WAD);

    //     if (_collateralUSD > _targetCR.usdMul(_debtUSD)) {
    //         uint256 requiredBorrow = RebalanceLogic.requiredBorrowUSD(
    //         _targetCR, _collateralUSD, _debtUSD, _offsetFactor
    //         );

    //         /// TODO: change this after MOCK
    //         uint256 actualBorrow = (_collateralUSD - _targetCR.usdMul(_debtUSD))
    //             .usdDiv(_targetCR - (USDWadRayMath.USD - _offsetFactor));

    //         assertEq(requiredBorrow, actualBorrow);
    //     }

    // }
}
