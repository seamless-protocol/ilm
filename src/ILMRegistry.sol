// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title ILMRegistry
/// @notice Registry for the deployed ILMs
contract ILMRegistry is AccessControl {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev role which can change strategy parameters
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  EnumerableSet.AddressSet private ilmSet;

  constructor(address initialAdmin) {
    _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
  }

  function addILM(address ilmAddress) external onlyRole(MANAGER_ROLE) {
    ilmSet.add(ilmAddress);
  }

  function removeILM(address ilmAddress) external onlyRole(MANAGER_ROLE) {
    ilmSet.remove(ilmAddress);
  }

  function countILM() external view returns (uint256) {
    return ilmSet.length();
  }

  function getAllILMs() external view returns (address[] memory) {
    return ilmSet.values();
  }

  function getILMat(uint256 index) external view returns (address) {
    return ilmSet.at(index);
  }
}