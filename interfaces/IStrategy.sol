// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/// @title IStrategy
/// @notice interface for Integration Liquiity Market strategies
/// @dev interface similar to 
interface IStrategy is IERC4626, IPausable, IOwnable, IUUPSUpgradeable {
}