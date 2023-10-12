// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IOracleMock } from "./IOracleMock.sol";

/// @title OracleMock
/// @dev Mocks the behavior of an AaveV3 oracle
contract OracleMock is IOracleMock {
    address public immutable collateralAsset;
    address public immutable borrowAsset;
    uint256 public constant borrowPrice = 1e8;
    uint256 public constant collateralPrice = 2000 * 1e8;

    constructor(address _collateralAsset, address _borrowAsset) {
        collateralAsset = _collateralAsset;
        borrowAsset = _borrowAsset;
    }

    /// @inheritdoc IOracleMock
    function getAssetPrice(address _token) public view returns (uint256 price) {
        price = _token == borrowAsset ? borrowPrice : collateralPrice;
    }
}
