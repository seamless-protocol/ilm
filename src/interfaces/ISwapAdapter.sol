// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/// @title ISwapAdapter
/// @notice interface for SwapAdapter contracts
interface ISwapAdapter {
    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @dev this is the only function that _must_ be implemented by a swap adapter - all DEX-specific logic
    /// is contained therein
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function executeSwap(
        address from,
        address to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount);
}
