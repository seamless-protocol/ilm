// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

/// @title BaseMainnetConstants
/// @notice Constants and addresses of deployed contracts on the Base Mainnet
abstract contract BaseMainnetConstants {
    address public constant BASE_MAINNET_WETH =
        0x4200000000000000000000000000000000000006;
    address public constant BASE_MAINNET_USDbC =
        0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;

    address public constant SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET =
        0x0E02EB705be325407707662C6f6d3466E939f3a0;

    address public constant AERODROME_ROUTER =
        0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // USDbC has 6 decimals
    uint256 public constant ONE_USDbC = 1e6;

    address public constant SEAMLESS_ATOKEN_IMPL = 0x27076A995387458da63b23d9AFe3df851727A8dB;
    address public constant SEAMLESS_STABLE_DEBT_TOKEN_IMPL = 0xb4D5e163738682A955404737f88FDCF15C1391bF;
    address public constant SEAMLESS_VARIABLE_DEBT_TOKEN_IMPL = 0x3800DA378e17A5B8D07D0144c321163591475977;
    address public constant SEAMLESS_TREASURY = 0x982F3A0e3183896f9970b8A9Ea6B69Cd53AF1089;
    address public constant SEAMLESS_INCENTIVES_CONTROLLER = 0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780;
}
