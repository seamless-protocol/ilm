 // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC5313 } from "@openzeppelin/contracts/interfaces/IERC5313.sol";

/// @title IOwnableStep
/// @notice interface to surface functions relating to Ownable2Step functionality
interface IOwnable2Step is IERC5313 {
    /// @notice Leaves the contract without owner. It will not be possible to call
    /// `onlyOwner` functions. Can only be called by the current owner.
    /// NOTE: Renouncing ownership will leave the contract without an owner,
    /// thereby disabling any functionality that is only available to the owner.
    function renounceOwnership() external;

    /// @notice Returns the address of the pending owner.
    /// @return nominatedOwner address of owner being nominated
    function pendingOwner() external view returns (address nominatedOwner);
    
    /// @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// Can only be called by the current owner.
    /// @param newOwner address of owner being nominated as new owner
    function transferOwnership(address newOwner) external;

    /// @notice The new owner accepts the ownership transfer.
    function acceptOwnership() external;

}