// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IILMRegistry } from "./interfaces/IILMRegistry.sol";

/// @title ILMRegistry
/// @notice Registry for the deployed ILMs
contract ILMRegistry is AccessControl, IILMRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev role which can change strategy parameters
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev holds all ilm Proxy contract addresses
    EnumerableSet.AddressSet private ilmSet;

    constructor(address initialAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MANAGER_ROLE, initialAdmin);
    }

    /// @inheritdoc IILMRegistry
    function addILM(address ilmAddress) external onlyRole(MANAGER_ROLE) {
        ilmSet.add(ilmAddress);

        emit ILMAdded(ilmAddress);
    }

    /// @inheritdoc IILMRegistry
    function removeILM(address ilmAddress) external onlyRole(MANAGER_ROLE) {
        ilmSet.remove(ilmAddress);

        emit ILMRemoved(ilmAddress);
    }

    /// @inheritdoc IILMRegistry
    function countILM() external view returns (uint256 ilmCount) {
        return ilmSet.length();
    }

    /// @inheritdoc IILMRegistry
    function getAllILMs() external view returns (address[] memory ilms) {
        return ilmSet.values();
    }

    /// @inheritdoc IILMRegistry
    function getILM(uint256 index) external view returns (address ilm) {
        return ilmSet.at(index);
    }
}
