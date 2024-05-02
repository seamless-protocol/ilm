// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

/// @title IILMRegistry
/// @notice Interface for ILMRegistry
interface IILMRegistry {
    /// @notice emitted when a new ILM proxy contract address is added to
    /// the ilmSet
    /// @param ilm address of ILM proxy contract
    event ILMAdded(address ilm);

    /// @notice emitted when an ILM proxy contract address is remove from
    /// the ilmSet
    /// @param ilm address of ILM proxy contract
    event ILMRemoved(address ilm);

    /// @notice adds the address of the ILM proxy contract to the ilmSet
    function addILM(address ilmAddress) external;

    /// @notice removes the address of the ILM proxy contract to the ilmSet
    function removeILM(address ilmAddress) external;

    /// @notice adds the address of the ILM proxy contract to the ilmSet
    /// @return ilmCount number of registered ilms
    function countILM() external view returns (uint256 ilmCount);

    /// @notice returns all registered ILM proxy contract addresses
    /// @return ilms registered ILM proxy contract addresses
    function getAllILMs() external view returns (address[] memory ilms);

    /// @notice returns the address of the ILM proxy contract at the specified index
    /// of the ilmSet
    /// @param index index of ILM proxy contract
    /// @return ilm address of ILM proxy contract
    function getILM(uint256 index) external view returns (address ilm);
}
