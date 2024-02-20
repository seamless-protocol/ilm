// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { SwapAdapterBase } from "./SwapAdapterBase.sol";
import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { IWrappedERC20PermissionedDeposit } from
    "../../interfaces/IWrappedERC20PermissionedDeposit.sol";
import { IWrappedTokenAdapter } from "../../interfaces/IWrappedTokenAdapter.sol";

/// @title WrappedTokenAdapter
/// @notice Adapter contract for executing swaps on aerodrome
contract WrappedTokenAdapter is SwapAdapterBase, IWrappedTokenAdapter {
    /// @notice emitted when the wrapper contract for a given WrappedToken is set
    /// @param from token to perform wrapping/unwrapping on
    /// @param to token which will be received after wrapping/unwrapping
    /// @param wrapper WrappedERC20PermissionedDeposit contract
    event WrapperSet(
        IERC20 from, IERC20 to, IWrappedERC20PermissionedDeposit wrapper
    );

    /// @notice emitted when the wrapper contract for a given WrappedToken is removed
    /// @param from token to perform wrapping/unwrapping on
    /// @param to token which will be received after wrapping/unwrapping
    event WrapperRemoved(IERC20 from, IERC20 to);

    mapping(
        IERC20 from
            => mapping(IERC20 to => IWrappedERC20PermissionedDeposit wrapper)
    ) public wrappers;

    constructor(address owner, address swapper) Ownable(owner) {
        _setSwapper(swapper);
    }

    /// @inheritdoc ISwapAdapter
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external onlySwapper returns (uint256 toAmount) {
        from.transferFrom(msg.sender, address(this), fromAmount);

        IWrappedERC20PermissionedDeposit wrapper = wrappers[from][to];

        from.approve(address(wrapper), fromAmount);

        if (address(wrapper.underlying()) == address(to)) {
            wrapper.withdraw(fromAmount);
        } else {
            wrapper.deposit(fromAmount);
        }

        to.transfer(address(beneficiary), fromAmount);

        // should always be 1:1 ratio
        return fromAmount;
    }

    /// @inheritdoc ISwapAdapter
    function setSwapper(address swapper) external onlyOwner {
        _setSwapper(swapper);
    }

    /// @inheritdoc IWrappedTokenAdapter
    function setWrapper(
        IERC20 from,
        IERC20 to,
        IWrappedERC20PermissionedDeposit wrapper
    ) external onlyOwner {
        if (address(wrappers[from][to]) != address(0)) {
            _removeWrapper(from, to);
        }

        wrappers[from][to] = wrapper;
        wrappers[to][from] = wrapper;

        emit WrapperSet(from, to, wrapper);
        emit WrapperSet(to, from, wrapper);
    }

    /// @inheritdoc IWrappedTokenAdapter
    function removeWrapper(IERC20 from, IERC20 to) external onlyOwner {
        _removeWrapper(from, to);
    }

    /// @notice removes a previously set wrapper for a given from/to token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    function _removeWrapper(IERC20 from, IERC20 to) internal {
        delete wrappers[from][to];
        delete wrappers[to][from];

        emit WrapperRemoved(from, to);
        emit WrapperRemoved(to, from);
    }
}
