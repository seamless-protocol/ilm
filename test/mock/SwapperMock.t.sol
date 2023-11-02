// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ISwapper } from "../../src/interfaces/ISwapper.sol";

/// @title SwapperMock
/// @dev Mocks the behavior of the Swapper contract
contract SwapperMock is Test, ISwapper {
    IERC20 public immutable collateralAsset;
    IERC20 public immutable borrowAsset;
    uint256 public constant borrowToCollateralOffset = 5e6; // 5% assuming basis is 1e8
    uint256 public constant collateralToBorrowOffset = 5e6; // 5% assuming basis is 1e8
    uint256 public constant BASIS = 1e8;
    IPriceOracleGetter public oracle;

    constructor(
        address _collateralAsset,
        address _borrowAsset,
        address _oracle
    ) {
        collateralAsset = IERC20(_collateralAsset);
        borrowAsset = IERC20(_borrowAsset);
        oracle = IPriceOracleGetter(_oracle);
    }

    /// @inheritdoc ISwapper
    function offsetFactor(IERC20 _from, IERC20 _to)
        public
        view
        returns (uint256 offset)
    {
        if (_from == collateralAsset && _to == borrowAsset) {
            offset = collateralToBorrowOffset;
        } else {
            offset = borrowToCollateralOffset;
        }
    }

    /// @inheritdoc ISwapper
    function swap(
        IERC20 _from,
        IERC20 _to,
        uint256 _fromAmount,
        address payable _beneficiary
    ) external returns (uint256 toAmount) {
        _from.transferFrom(_beneficiary, address(this), _fromAmount);

        uint256 fromPriceUSD = oracle.getAssetPrice(address(_from));
        uint256 toPriceUSD = oracle.getAssetPrice(address(_to));

        uint8 fromDecimals = IERC20Metadata(address(_from)).decimals();
        uint8 toDecimals = IERC20Metadata(address(_to)).decimals();

        if (fromDecimals < toDecimals) {
            toAmount = (
                (_fromAmount * fromPriceUSD) * 10 ** (toDecimals - fromDecimals)
            ) / toPriceUSD;
        } else {
            toAmount = ((_fromAmount * fromPriceUSD) / toPriceUSD)
                / 10 ** (fromDecimals - toDecimals);
        }

        /// mock account for the offset of DEX swaps
        toAmount -= (toAmount * offsetFactor(_from, _to)) / BASIS;

        //IERC20(_to).transfer(_beneficiary, toAmount);
        deal(address(_to), _beneficiary, toAmount);
    }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function getRoute(address _from, address _to)
        external
        returns (Step[] memory steps)
    { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function setRoute(address from, address to, Step[] calldata steps)
        external
    { }
}
