// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

interface IOracleMock {
    /// @notice mocks fetching of an asset's price
    /// @param _token address of token to fetch price for
    /// @return price price of asset
    function getAssetPrice(address _token) external view returns (uint256 price);
}
