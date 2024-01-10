// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title ISwapAdapter
/// @notice interface for SwapAdapter contracts
interface ISwapAdapter {
    /// @notice thrown when attempting to call Swapper-gated functions
    error NotSwapper();

    /// @notice emitted when the Swapper contract is set for a given adapter
    /// @param swapper address of Swapper contract
    event SwapperSet(address swapper);

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @dev this is a function that _must_ be implemented by a swap adapter - all DEX-specific logic
    /// is contained therein
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount);

    /// @notice sets the address of the Swapper contract
    /// @dev this is a function that _must_ be implemented by a swap adapter
    /// @param swapper address of Swapper contract
    function setSwapper(address swapper) external;

    /// @notice returns the address of Swapper contract
    /// @dev this is a function that _must_ be implemented by a swap adapter - permissions
    /// for calling swaps are granted to this address
    /// @return swapper address of Swapper contract
    function getSwapper() external view returns (address swapper);
}
