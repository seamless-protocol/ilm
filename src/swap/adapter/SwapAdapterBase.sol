// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";

/// @title SwapAdapterBase
/// @notice Base adapter contract for all swap adapters
/// @dev should be inherited and overridden by all SwapAdapter implementations
abstract contract SwapAdapterBase is Ownable2Step, ISwapAdapter {
    address public swapper;

    modifier onlySwapper() {
        if (swapper != msg.sender) {
            revert NotSwapper();
        }
        _;
    }

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function _executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) internal virtual returns (uint256 toAmount) {
        // override with adapter specific swap logic
    }

    /// @notice sets the address of the Swapper contract
    /// @param _swapper address of Swapper contract
    function _setSwapper(address _swapper) internal virtual {
        swapper = _swapper;

        emit SwapperSet(_swapper);
    }
}
