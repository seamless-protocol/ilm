// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { SwapAdapterBaseStorage as Storage } from
    "../../storage/SwapAdapterBaseStorage.sol";

/// @title SwapAdapterBase
/// @notice Base adapter contract for all swap adapters
/// @dev should be inherited and overridden by all SwapAdapter implementations
abstract contract SwapAdapterBase is Ownable2StepUpgradeable, ISwapAdapter {
    modifier onlySwapper() {
        if (Storage.layout().swapper != msg.sender) {
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

    /// @notice returns the address of Swapper contract
    /// @return swapper address of Swapper contract
    function _getSwapper() internal view virtual returns (address swapper) {
        return Storage.layout().swapper;
    }

    /// @notice sets the address of the Swapper contract
    /// @param swapper address of Swapper contract
    function _setSwapper(address swapper) internal virtual {
        Storage.layout().swapper = swapper;

        emit SwapperSet(swapper);
    }
}
