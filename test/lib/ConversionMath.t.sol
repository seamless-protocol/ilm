// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";

import { ConversionMath } from "../../src/libraries/math/ConversionMath.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

/// @title ConversionMathTest 
/// @dev ConversionMath library unit tests
contract ConversionMathTest is Test {
    using USDWadRayMath for uint256;

    /// @dev ensures that converting assets amounts to USD amounts results in the expected value,
    /// for a range of inputs
    /// @param assetAmount fuzzed amount of asset to convert in USD
    /// @param priceInUSD fuzzed price of asset in USD
    /// @param assetDecimals fuzzed value of asset decimals
    function testFuzz_convertAssetToUSD(
        uint256 assetAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) public {
        // prevent overflows
        assetDecimals = bound(assetDecimals, 0, 18); // assume tokens with no more than 18 decimals would be used as assets
        priceInUSD = bound(priceInUSD, 0, 1 ** 12);
        assetAmount = bound(assetAmount, 0, 5 * 10 ** 60);

        uint256 usdAmount = ConversionMath.convertAssetToUSD(
            assetAmount, priceInUSD, assetDecimals
        );

        assertEq(
            usdAmount, assetAmount * priceInUSD / (10 ** assetDecimals)
        );
    }

    /// @dev ensures that converting USD amounts to asset amounts results in the expected value,
    /// for a range of inputs
    /// @param usdAmount fuzzed amount of USD to convert to asset
    /// @param priceInUSD fuzzed price of asset in USD
    /// @param assetDecimals fuzzed value of asset decimals
    function testFuzz_convertUSDtoAsset(
        uint256 usdAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) public {
        vm.assume(assetDecimals <= 18 && assetDecimals != 0); // assume no tokens with more than 18 decimals would be used as assets
        vm.assume(priceInUSD <= 250_000 * 10 ** 8 && priceInUSD != 0); // assume no token has a price larger than 250000 USD
        vm.assume(usdAmount <= 5 * 10 ** 60 && usdAmount != 0); // assume no astronomical value of USD to be converted

        uint256 assetAmount = ConversionMath.convertUSDToAsset(
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
}