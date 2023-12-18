// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { Step } from "../types/DataTypes.sol";

library SwapperStorage {
    /// @dev struct containing all state for the Swapper contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.Swapper
    struct Layout {
        mapping(IERC20 from => mapping(IERC20 to => uint256 offsetUSD))
            offsetUSD;
        mapping(IERC20 from => mapping(IERC20 to => Step[] steps)) route;
        EnumerableSet.AddressSet strategies;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.Swapper")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT =
        0xd13913e6f5971fa78083bb454f0bd9d937359fbaf7a5296aa0498a9631cf8b00;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
