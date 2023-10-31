// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

/// @title RebalanceLogicHarness
/// @dev RebalanceLogicHarness contract which exposes RebalanceLogic library functions
contract RebalanceLogicHarness is RebalanceLogicContext {
    using USDWadRayMath for uint256;

    //address public SUPPLIER = address(123123123);
    /// @dev sets up testing context
    function setUp() public virtual override {
        super.setUp();

        LoanLogic.supply(lendingPool, assets.collateral, (MINT_AMOUNT / 10));
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    function test_rebalanceUp_bringsCollateralRatioToTarget() public {
        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
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

        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);

        targetCR = 3.5e8;

        state = LoanLogic.getLoanState(lendingPool);
        currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        ratio = RebalanceLogic.rebalanceDown(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(
        uint256 targetRatio
    ) public {
        // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
        vm.assume(targetRatio > 1.34e8);
        vm.assume(targetRatio < 50e8);

        targetCR = targetRatio;
        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
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

        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);

        vm.assume(targetRatio > 1.35e8);
        vm.assume(targetRatio < 5e8);

        targetCR = targetRatio;

        state = LoanLogic.getLoanState(lendingPool);
        currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        ratio = RebalanceLogic.rebalanceDown(
            lendingPool, assets, state, currentCR, targetCR, oracle, swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
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
        vm.assume(priceInUSD <= 250000 * 10 ** 8); // assume no token has a price larger than 250000 USD
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
        vm.assume(priceInUSD <= 250000 * 10 ** 8 && priceInUSD != 0); // assume no token has a price larger than 250000 USD
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
}
