// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/// @title TestConstants
/// @notice configuration and constants used in tests
abstract contract TestConstants {
    string public constant BASE_MAINNET_RPC_URL = "BASE_MAINNET_RPC_URL";

    address public constant BASE_MAINNET_WETH =
        0x4200000000000000000000000000000000000006;
    address public constant BASE_MAINNET_USDbC =
        0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public constant BASE_MAINNET_CbETH =
        0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;

    address public constant SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET =
        0x0E02EB705be325407707662C6f6d3466E939f3a0;

    // USDbC has 6 decimals
    uint256 public constant ONE_USDbC = 1e6;
}
