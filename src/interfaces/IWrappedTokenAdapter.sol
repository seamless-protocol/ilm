// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IWrappedERC20PermissionedDeposit } from
    "../interfaces/IWrappedERC20PermissionedDeposit.sol";

/// @title IWrappedTokenAdapter
/// @notice interface for WrappedTokenAdapter functionality
interface IWrappedTokenAdapter {
    /// @notice sets the wrapper contract for a given token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    /// @param wrapper WrappedERC20PermissionedDeposit contract pertaining to from/to tokens
    function setWrapper(
        IERC20 from,
        IERC20 to,
        IWrappedERC20PermissionedDeposit wrapper
    ) external;

    /// @notice removes a previously set wrapper for a given from/to token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    function removeWrapper(IERC20 from, IERC20 to) external;
}
