// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IRewardsController } from
    "@aave-periphery/contracts/rewards/interfaces/IRewardsController.sol";

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

    address public constant AERODROME_ROUTER =
        0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    address public constant CHAINLINK_CBETH_USD_ORACLE =
        0xd7818272B9e248357d13057AAb0B417aF31E817d;

    // USDbC has 6 decimals
    uint256 public constant ONE_USDbC = 1e6;

    address public constant SEAMLESS_ATOKEN_IMPL =
        0x27076A995387458da63b23d9AFe3df851727A8dB;
    address public constant SEAMLESS_STABLE_DEBT_TOKEN_IMPL =
        0xb4D5e163738682A955404737f88FDCF15C1391bF;
    address public constant SEAMLESS_VARIABLE_DEBT_TOKEN_IMPL =
        0x3800DA378e17A5B8D07D0144c321163591475977;
    address public constant SEAMLESS_CBETH_INTEREST_RATE_STRATEGY_ADDRESS =
        0xcEd653F5C689eC80881b1A8b9Ab2b64DF2B963Bd;
    address public constant SEAMLESS_TREASURY =
        0x982F3A0e3183896f9970b8A9Ea6B69Cd53AF1089;
    address public constant SEAMLESS_INCENTIVES_CONTROLLER =
        0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780;

    address public constant SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS =
        0x639d2dD24304aC2e6A691d8c1cFf4a2665925fee;
    IRewardsController public constant REWARDS_CONTROLLER =
        IRewardsController(0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780);
    IPoolConfigurator public constant POOL_CONFIGURATOR =
        IPoolConfigurator(0x7B08A77539A50218c8fB4B706B87fb799d3505A0);
    IAaveOracle public constant AAVE_ORACLE =
        IAaveOracle(0xFDd4e83890BCcd1fbF9b10d71a5cc0a738753b01);
    IPool public constant POOL =
        IPool(0x8F44Fd754285aa6A2b8B9B97739B79746e0475a7);

    uint256 public constant MAX_SUPPLY_CAP = 68719476735;
}
