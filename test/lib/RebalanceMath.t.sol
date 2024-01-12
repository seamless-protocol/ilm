// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { ConversionMath } from "../../src/libraries/math/ConversionMath.sol";
import { RebalanceMath } from "../../src/libraries/math/RebalanceMath.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

/// @title RebalanceMathTest
/// @dev RebalanceMath library unit tests
contract RebalanceMathTest is Test {
    using USDWadRayMath for uint256;

    /// @dev ensures that calculating the collateral ratio gives the expected value, for a range
    /// of inputs
    /// @param collateralUSD fuzzed value of collateral held by contract in USD
    /// @param debtUSD fuzzed value of debt held by contract in USD
    function testFuzz_collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
        public
    {
        debtUSD = bound(
            debtUSD, 0, (type(uint256).max - debtUSD / 2) / USDWadRayMath.USD
        );
        /// assume that collateral is always larger than debt because otherwise
        /// position would have been liquidated
        collateralUSD = bound(
            collateralUSD,
            debtUSD,
            (type(uint256).max - debtUSD / 2) / USDWadRayMath.USD
        );

        uint256 ratio;

        if (debtUSD == 0) {
            ratio = RebalanceMath.collateralRatioUSD(collateralUSD, debtUSD);
            assertEq(ratio, type(uint256).max);
        } else {
            ratio = RebalanceMath.collateralRatioUSD(collateralUSD, debtUSD);
            assertEq(ratio, collateralUSD.usdDiv(debtUSD));
        }
    }

    /// @dev ensures that offsetting a USD value down results in the expected value,
    /// for a range of inputs
    /// @param a fuzzed value to offset down
    /// @param offsetUSD fuzzed value of _offsetUSD
    function testFuzz_offset_USDAmountDown(uint256 a, uint256 offsetUSD)
        public
    {
        offsetUSD = bound(offsetUSD, 0, USDWadRayMath.USD - 1);

        uint256 amount = RebalanceMath.offsetUSDAmountDown(a, offsetUSD);

        // ensure overflows are accounted for
        if (a <= type(uint256).max / (USDWadRayMath.USD - offsetUSD)) {
            assertEq(
                amount,
                (a * (USDWadRayMath.USD - offsetUSD) / USDWadRayMath.USD)
            );
        } else {
            assertEq(
                amount,
                (a / USDWadRayMath.USD) * (USDWadRayMath.USD - offsetUSD)
            );
        }
    }

    /// @dev ensures that requiredBorrowUSD returns the value required to reach target CR
    /// @param ltv fuzzed value of loan-to-value ratio
    /// @param targetCR fuzzed value of collateral ratio target
    /// @param collateralUSD fuzzed value of collateral in USD
    /// @param debtUSD fuzzed value of debt in USD
    /// @param offsetFactor fuzzed value of offset (from 0 - 1 USD)
    function testFuzz_requiredBorrowUSD(
        uint256 ltv,
        uint256 targetCR,
        uint256 collateralUSD,
        uint256 debtUSD,
        uint256 offsetFactor
    ) public {
        /// need a minimum LTV and maximum LTV to bound all other variables
        /// LTV must always be < 1 as we are working with overcallateralized positions
        ltv = bound(ltv, 0.01e8, 0.9e8);
        /// offsetFactor is a value up to 1e8
        offsetFactor = bound(offsetFactor, 0, 1e8);
        /// target CR must be at least 1 / LTV
        /// max bound is set to be very high because at that point it is as if we have 0 debt (debt is neglible)
        targetCR = bound(targetCR, (USDWadRayMath.USD).usdDiv(ltv), 1e26);

        /// assume less than 3 trillion USD collateral, and more than 1 USD
        collateralUSD = bound(collateralUSD, 1e8, 3e20);

        debtUSD = bound(debtUSD, 0, collateralUSD.usdMul(ltv));

        if (collateralUSD > targetCR.usdMul(debtUSD)) {
            uint256 requiredBorrow = RebalanceMath.requiredBorrowUSD(
                targetCR, collateralUSD, debtUSD, offsetFactor
            );

            uint256 actualBorrow = (collateralUSD - targetCR.usdMul(debtUSD))
                .usdDiv(targetCR - (USDWadRayMath.USD - offsetFactor));

            assertEq(requiredBorrow, actualBorrow);
        }
    }
}
