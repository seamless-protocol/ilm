// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ISwapper } from "../../src/interfaces/ISwapper.sol";

/// @title SwapperMock
/// @dev Mocks the behavior of the Swapper contract
contract SwapperMock is ISwapper {
    address public immutable collateralAsset;
    address public immutable borrowAsset;
    uint256 public constant borrowToCollateralOffset = 1e7; // 10% assuming basis is 1e8
    uint256 public constant collateralToBorrowOffset = 2e7; // 20% assuming basis is 1e8
    uint256 public constant BASIS = 1e8;

    constructor(address _collateralAsset, address _borrowAsset)  {
        collateralAsset = _collateralAsset;
        borrowAsset = _borrowAsset;
    }

    /// @inheritdoc ISwapper
    function offsetFactor(address _from, address _to) public view returns (uint256 offset) {
       if( _from == collateralAsset && _to == borrowAsset ) {
           offset = collateralToBorrowOffset;
       } else {
           offset = borrowToCollateralOffset;
       }
    } 

    /// @inheritdoc ISwapper
    function swap(
        address _from,
        address _to,
        uint256 _fromAmount,
        address payable _beneficiary
    ) external returns (uint256 _toAmount) {
        _toAmount = _fromAmount;
        IERC20(_from).transferFrom(_beneficiary, address(this),  _fromAmount);
        
        /// mock account for the offset of DEX swaps 
        _toAmount -= _fromAmount * offsetFactor(_from, _to) / BASIS;
        IERC20(_to).transfer(_beneficiary, _toAmount);
    }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function getRoute(address _from, address _to) external returns (Step[] memory steps) {}
    
    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function setRoute(address from, address to, Step[] calldata steps) external {}
}
