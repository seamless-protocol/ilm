// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

library SwapAdapterBaseStorage {
    /// @dev struct containing all state for the SwapAdapterBase contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.SwapAdapterBase
    struct Layout {
        address swapper;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.SwapAdapterBase")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT =
        0xebbcbb6f4bc0510bac5105d82440cb1f3fa3634785f911c43618c35177456000;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
