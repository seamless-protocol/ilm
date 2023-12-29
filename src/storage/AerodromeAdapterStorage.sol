// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IRouter } from "../vendor/aerodrome/IRouter.sol";

library AerodromeAdapterStorage {
    /// @dev struct containing all state for the AerodromeAdapter contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.AerodromeAdapter
    struct Layout {
        mapping(IERC20 from => mapping(IERC20 to => IRouter.Route[] routes))
            swapRoutes;
        mapping(IERC20 from => mapping(IERC20 to => bool isStable)) isPoolStable;
        mapping(address pair => address factory) pairFactory;
        address router;
        address poolFactory;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.AerodromeAdapter")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT =
        0xe20fadfe51c05810cf8049153a6d3327f8bd31f8cadde6b0efd76ce5573f2600;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
