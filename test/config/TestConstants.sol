// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

abstract contract TestConstants {
  string public constant BASE_MAINNET_RPC_URL = "BASE_MAINNET_RPC_URL";

  address public constant BASE_MAINNET_WETH = 0x4200000000000000000000000000000000000006;
  address public constant BASE_MAINNET_USDbC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;

  // USDbC has 6 decimals
  uint256 public constant ONE_USDbC = 1e6;
}