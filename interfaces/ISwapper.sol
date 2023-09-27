// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/// @title ISwapper
/// @notice interface for Swapper contract
/// @dev Swapper contract functions as registry and router for Swapper Adapters
interface ISwapper {
    /// @notice returns the address of an adapter for a given swap path
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @return adapter address of adapter
    function getAdapter(address from, address to) external returns (address adapter);

    /// @notice sets the adapter address for a given swap path
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param adapter address of adapter
    function setAdapter(address from, address to, address adapter) external;

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function swap(address from, address to, uint256 fromAmount, address payable beneficiary) external returns (uint256 toAmount);
}