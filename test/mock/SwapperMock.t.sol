// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { Step } from "../../src/types/DataTypes.sol";

import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";

/// @title SwapperMock
/// @dev Mocks the behavior of the Swapper contract
contract SwapperMock is Test, ISwapper {
    IERC20 public immutable collateralAsset;
    IERC20 public immutable borrowAsset;
    uint256 public realBorrowToCollateralOffset = 5e6; // 5% assuming basis is 1e8
    uint256 public realCollateralToBorrowOffset = 5e6; // 5% assuming basis is 1e8
    uint256 public estimatedBorrowToCollateralOffset = 5e6; // 5% assuming basis is 1e8
    uint256 public estimatedCollateralToBorrowOffset = 5e6; // 5% assuming basis is 1e8

    uint256 public constant BASIS = 1e8;
    IPriceOracleGetter public oracle;

    mapping(IERC20 token => bool isWrapped) public isWrapped;

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
            offset = estimatedCollateralToBorrowOffset;
        } else {
            offset = estimatedBorrowToCollateralOffset;
        }
    }

    /// @dev returns the real offset factor
    function realOffsetFactor(IERC20 _from, IERC20 _to)
        public
        view
        returns (uint256 offset)
    {
        if (_from == collateralAsset && _to == borrowAsset) {
            offset = realCollateralToBorrowOffset;
        } else {
            offset = realBorrowToCollateralOffset;
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
        // IMPORTANT NOTE:
        // To allow for an "equity gain" from a swap,  offsetFactor can be set above 1e8
        // (it cannot be in production)
        uint256 offset = realOffsetFactor(_from, _to);
        if (offset < BASIS) {
            toAmount -= (toAmount * offset) / BASIS;
        } else {
            toAmount += (toAmount * (offset - BASIS)) / BASIS;
        }

        if (isWrapped[_from]) {
            WrappedCbETH(address(_from)).withdraw(_fromAmount);
        }

        if (isWrapped[_to]) {
            // handle deposit to wrapped token
            WrappedCbETH wrappedToken = WrappedCbETH(address(_to));
            IERC20 underlying = wrappedToken.underlying();
            deal(address(underlying), address(this), underlying.balanceOf(address(this)) + toAmount);
            underlying.approve(address(wrappedToken), toAmount);
            wrappedToken.deposit(toAmount);
            _to.transfer(_beneficiary, toAmount);
        } else {
            deal(address(_to), _beneficiary, _to.balanceOf(_beneficiary) + toAmount);
        }
    }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function getRoute(IERC20 _from, IERC20 _to)
        external
        returns (Step[] memory steps)
    { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function setRoute(IERC20 from, IERC20 to, Step[] calldata steps) external { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function setOffsetFactor(IERC20 from, IERC20 to, uint256 offsetUSD)
        external
    { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function removeRoute(IERC20 from, IERC20 to) external { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function setOffsetDeviationUSD(uint256 offsetDeviationUSD) external { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function setOracle(IPriceOracleGetter oracles) external { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function getOracle() external view returns (IPriceOracleGetter) { }

    /// @inheritdoc ISwapper
    /// @dev unimplemented in mock
    function getOffsetDeviationUSD()
        external
        view
        returns (uint256 offsetDeviationUSD)
    { }

    function setOffsets(
        uint256 _borrowToCollateralOffset,
        uint256 _collateralToBorrowOffset
    ) external {
        estimatedBorrowToCollateralOffset = _borrowToCollateralOffset;
        estimatedCollateralToBorrowOffset = _collateralToBorrowOffset;
    }

    function setRealOffsets(
        uint256 _borrowToCollateralOffset,
        uint256 _collateralToBorrowOffset
    ) external {
        realBorrowToCollateralOffset = _borrowToCollateralOffset;
        realCollateralToBorrowOffset = _collateralToBorrowOffset;
    }

    function setWrapped(
        IERC20 wrappedToken,
        bool _isWrapped
    ) external {
        isWrapped[wrappedToken] = _isWrapped;
    }
}
