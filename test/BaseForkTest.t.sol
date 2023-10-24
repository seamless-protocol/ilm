// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";

import { TestConstants } from "./config/TestConstants.sol";

/// @title BaseForkTest
/// @dev Base contract for Base forking test cases.
abstract contract BaseForkTest is Test, TestConstants {
    /// @dev Fetches and stores the BASE MAINNET RPC URL from a local .env file using the passed string as a key.
    string internal BASE_RPC_URL = vm.envString("BASE_MAINNET_RPC_URL");

    /// @dev Identifier for the simulated Base fork.
    /// @notice Fork is created, available for selection, and selected by default.
    uint256 internal baseFork = vm.createSelectFork(BASE_RPC_URL);
}