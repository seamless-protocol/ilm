// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";

contract MockAaveOracle is IAaveOracle {
    mapping(address => uint256) public assetPrice;

    function BASE_CURRENCY() external pure override returns (address) {
        return address(0);
    }

    function BASE_CURRENCY_UNIT() external pure override returns (uint256) {
        return (1e8);
    }

    function latestAnswer() external pure returns (int256) {
        return 1e8;
    }

    function getAssetPrice(address asset)
        public
        view
        override
        returns (uint256)
    {
        return assetPrice[asset];
    }

    function getAssetsPrices(address[] calldata assets)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256[] memory prices = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            prices[i] = getAssetPrice(assets[i]);
        }
        return prices;
    }

    function ADDRESSES_PROVIDER()
        external
        view
        override
        returns (IPoolAddressesProvider)
    { }

    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external override { }

    function setFallbackOracle(address fallbackOracle) external override { }

    function getSourceOfAsset(address asset)
        external
        view
        override
        returns (address)
    { }

    function getFallbackOracle() external view override returns (address) { }

    function setAssetPrice(address asset, uint256 price) external {
        assetPrice[asset] = price;
    }
}
