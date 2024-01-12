// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { USDWadRayMath } from "./USDWadRayMath.sol";

library ConversionMath {
    using USDWadRayMath for uint256;

    /// @dev decimals of USD prices as per oracle
    uint8 internal constant USD_DECIMALS = 8;

    /// @notice converts a asset amount to its usd value
    /// @param assetAmount amount of asset
    /// @param priceInUSD price of asset in USD
    /// @return usdAmount amount of USD after conversion
    function convertAssetToUSD(
        uint256 assetAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) internal pure returns (uint256 usdAmount) {
        usdAmount = assetAmount * priceInUSD / (10 ** assetDecimals);
    }

    /// @notice converts a USD amount to its token value
    /// @param usdAmount amount of USD
    /// @param priceInUSD price of asset in USD
    /// @return assetAmount amount of asset after conversion
    function convertUSDToAsset(
        uint256 usdAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) internal pure returns (uint256 assetAmount) {
        if (USD_DECIMALS > assetDecimals) {
            assetAmount = usdAmount.usdDiv(priceInUSD)
                / (10 ** (USD_DECIMALS - assetDecimals));
        } else {
            assetAmount = usdAmount.usdDiv(priceInUSD)
                * (10 ** (assetDecimals - USD_DECIMALS));
        }
    }
}
