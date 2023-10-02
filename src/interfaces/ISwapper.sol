// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ISwapAdapter } from "./ISwapAdapter.sol";

/// @title ISwapper
/// @notice interface for Swapper contract
/// @dev Swapper contract functions as registry and router for Swapper Adapters
interface ISwapper {
    /// @dev struc to encapsulate a single swap step for a given swap route
    struct Step {
        /// @dev from address of token to swap from
        address from;
        /// @dev to address of token to swap to
        address to;
        /// @dev cast address of swap adapter
        ISwapAdapter adapter;
    }

    /// @notice returns the steps of a swap route
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @return steps array of swap steps needed to end up with `to` token from `from` token
    function getRoute(address from, address to) external returns (Step[] memory steps);

    /// @notice sets the a steps of a swap route
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param steps  array of swap steps needed to end up with `to` token from `from` token
    function setRoute(address from, address to, Step[] calldata steps) external;

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function swap(address from, address to, uint256 fromAmount, address payable beneficiary) external returns (uint256 toAmount);
}