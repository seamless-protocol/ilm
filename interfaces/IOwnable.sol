 // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC5313 } from "@openzeppelin/contracts/interfaces/IERC5313.sol";

/// @title IOwnable
/// @notice interface to surface functions relating to Ownable functionality
interface IOwnable is IERC5313 {
    /// @notice Leaves the contract without owner. It will not be possible to call
    /// `onlyOwner` functions. Can only be called by the current owner.
    /// NOTE: Renouncing ownership will leave the contract without an owner,
    /// thereby disabling any functionality that is only available to the owner.
    function renounceOwnership() external;

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;

}