// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/// @title IPausable
/// @notice interface for Pausable functionality
interface IPausable {
    /// @notice set paused state to true
    function pause() external;

    /// @notice set paused state to false
    function unpause() external;
     
    /// @notice returns paused state
    /// @param state true if paused, false if unpaused
    function paused() external view returns (bool state);
}

 