// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

library ConversionMath {
    /// @dev decimals of USD prices as per oracle
    uint8 internal constant USD_DECIMALS = 8;

    /// @notice converts a asset amount to its usd value
    /// @param assetAmount amount of asset
    /// @param priceInUSD price of asset in USD
    /// @param assetDecimals number of decimals of the asset
    /// @return usdAmount amount of USD after conversion
    function convertAssetToUSD(
        uint256 assetAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) internal pure returns (uint256 usdAmount) {
        usdAmount = Math.mulDiv(assetAmount, priceInUSD, 10 ** assetDecimals);
    }

    /// @notice converts a USD amount to its token value
    /// @param usdAmount amount of USD
    /// @param priceInUSD price of asset in USD
    /// @param assetDecimals number of decimals of the asset
    /// @return assetAmount amount of asset after conversion
    function convertUSDToAsset(
        uint256 usdAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) internal pure returns (uint256 assetAmount) {
        assetAmount = Math.mulDiv(usdAmount, 10 ** assetDecimals, priceInUSD);
    }
}
