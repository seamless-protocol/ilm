// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { WrappedTokenAdapterStorage as Storage } from
    "../../storage/WrappedTokenAdapterStorage.sol";
import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { IWrappedERC20PermissionedDeposit } from
    "../../interfaces/IWrappedERC20PermissionedDeposit.sol";

/// @title WrappedTokenAdapter
/// @notice Adapter contract for executing swaps on aerodrome
contract WrappedTokenAdapter is Ownable2StepUpgradeable, ISwapAdapter {
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

    /// @notice initializing function of adapter
    /// @param owner address of adapter owner
    function WrappedTokenAdapter__Init(address owner) external initializer {
        __Ownable_init(owner);
    }

    /// @inheritdoc ISwapAdapter
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable // no need for beneficiary param since sent to msg.sender
    ) external returns (uint256 toAmount) {
        Storage.Layout storage $ = Storage.layout();

        from.transferFrom(msg.sender, address(this), fromAmount);

        IWrappedERC20PermissionedDeposit wrapper = $.wrappers[from][to];

        from.approve(address(wrapper), fromAmount);

        if (address(wrapper.underlying()) == address(to)) {
            wrapper.withdraw(fromAmount);
        } else {
            wrapper.deposit(fromAmount);
        }

        // should always be 1:1 ratio
        return fromAmount;
    }

    /// @notice sets the wrapper contract for a given token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    /// @param wrapper WrappedERC20PermissionedDeposit contract pertaining to from/to tokens
    function setWrapper(
        IERC20 from,
        IERC20 to,
        IWrappedERC20PermissionedDeposit wrapper
    ) external onlyOwner {
        Storage.Layout storage $ = Storage.layout();

        if (address($.wrappers[from][to]) != address(0)) {
            _removeWrapper(from, to);
        }

        $.wrappers[from][to] = wrapper;

        emit WrapperSet(from, to, wrapper);
    }

    /// @notice removes a previously set wrapper for a given from/to token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    function removeWrapper(IERC20 from, IERC20 to) external onlyOwner {
        _removeWrapper(from, to);
    }

    /// @notice removes a previously set wrapper for a given from/to token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    function _removeWrapper(IERC20 from, IERC20 to) internal {
        delete Storage.layout().wrappers[from][to];

        emit WrapperRemoved(from, to);
    }
}
