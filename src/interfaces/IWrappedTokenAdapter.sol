// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IWrappedERC20PermissionedDeposit } from
    "../interfaces/IWrappedERC20PermissionedDeposit.sol";

/// @title IWrappedTokenAdapter
/// @notice interface for WrappedTokenAdapter functionality
interface IWrappedTokenAdapter {
    /// @notice initializing function of adapter
    /// @param owner address of adapter owner
    function WrappedTokenAdapter__Init(address owner) external;

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

    /// @notice returns wrapper contract for a given from/to token pair
    /// @param from token to wrap/unwrap
    /// @param to token received after wrapping/unwrapping
    /// @return wrapper WrappedERC20PermissionedDeposit contract pertaining to from/to tokens
    function getWrapper(IERC20 from, IERC20 to)
        external
        view
        returns (IWrappedERC20PermissionedDeposit wrapper);
}
