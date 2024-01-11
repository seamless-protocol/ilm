// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

/// @title IPausable
/// @notice interface for Pausable functionality
interface IPausable {
    /// @notice the operation failed because the contract is paused
    error EnforcedPause();

    /// @notice set paused state to true
    function pause() external;

    /// @notice set paused state to false
    function unpause() external view;

    /// @notice returns paused state
    /// @param state true if paused, false if unpaused
    function paused() external view returns (bool state);
}
