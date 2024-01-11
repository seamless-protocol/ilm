// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IWrappedERC20PermissionedDeposit } from
    "../interfaces/IWrappedERC20PermissionedDeposit.sol";

library WrappedTokenAdapterStorage {
    /// @dev struct containing all state for the WrappedTokenAdapter contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.WrappedTokenAdapter
    struct Layout {
        mapping(
            IERC20 from
                => mapping(
                    IERC20 to => IWrappedERC20PermissionedDeposit wrapper
                )
            ) wrappers;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.WrappedTokenAdapter")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT =
        0x25b70c849dde52d8ddadc20d855caa6e4102bdc5328ba5593a0d5c3e9ab8af00;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
