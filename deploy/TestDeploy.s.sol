// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "forge-std/script.sol";
import { BaseMainnetConstants } from "./config/BaseMainnetConstants.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/swap/Swapper.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { ConfiguratorInputTypes } from 
    "@aave/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import { IRouter } from "../src/vendor/aerodrome/IRouter.sol";
import {
    WrappedCbETH,
    IWrappedERC20PermissionedDeposit
} from "../src/tokens/WrappedCbETH.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../src/LoopStrategy.sol";
import { WrappedTokenAdapter } from
    "../src/swap/adapter/WrappedTokenAdapter.sol";
import { AerodromeAdapter } from "../src/swap/adapter/AerodromeAdapter.sol";

contract TestDeploy is Script, BaseMainnetConstants {

  IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);
  IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
  IPoolAddressesProvider public constant poolAddressesProvider = IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);

  uint256 deployerPrivateKey;
  address deployerAddress;


  // WrappedCbETH: "0xC0b5989029494BAB724DB9D35A6A8E50bC683241",
  // Swapper: "0x29610df4f761460c6562B26DE06f44E2C7E5c9A7",
  // WrappedTokenAdapter: "0x2ea8D5975de484B7f2f3dc4AEaE9c0e23aaf61A3",
  // AerodromeAdapter: "0x32A7157f1C656D87726B53Ac5086DDCFDC22C19e",
  // Strategy: "0xbf7163E07Cb778E3D6216d249Bd64fa7c86B6Da2",


  // WrappedCbETH public wrappedCbETH = WrappedCbETH(0xA72B37c09527765Ae41fAf6C58cFA1732d257a38);
  // Swapper public swapper = Swapper(0x3F66221849eBf604BD64Ef39cb61c707b61D1b61);
  // WrappedTokenAdapter public wrappedTokenAdapter = WrappedTokenAdapter(0x6D18cDF17Fb977b3bfD020fb875Ea943e1e4e50d);
  // AerodromeAdapter public aerodromeAdapter = AerodromeAdapter(0x8a1c6C129e6bb101c769CFE774c1C78b55fb78e3);
  LoopStrategy public strategy = LoopStrategy(0xbf7163E07Cb778E3D6216d249Bd64fa7c86B6Da2);

  function run() public {
      deployerPrivateKey = vm.envUint("DEPLOYER_PK");
      deployerAddress = vm.addr(deployerPrivateKey);

      console.log(strategy.name());
      console.log(strategy.symbol());

      // console.log("col", strategy.collateral());
      // console.log("equ", strategy.equity());

      // console.log("cb balance", CbETH.balanceOf(deployerAddress));

      // console.log("lp balance", IERC20(address(strategy)).balanceOf(deployerAddress));

      // console.log("interest rate strategy", IPool(poolAddressesProvider.getPool()).getReserveData(address(CbETH)).interestRateStrategyAddress);

      // vm.startBroadcast(deployerPrivateKey);
      // uint256 depositAmount = 1000000000000000000;
      // CbETH.approve(address(strategy), depositAmount);
      // strategy.deposit(depositAmount, deployerAddress);
      // vm.stopBroadcast();

      // vm.startBroadcast(deployerPrivateKey);
      // strategy.redeem(10000000000, deployerAddress, deployerAddress);
      // vm.stopBroadcast();

      // console.log("lp balance", IERC20(address(strategy)).balanceOf(deployerAddress));

      // console.log("col", strategy.collateral());
      // console.log("equ", strategy.equity());
  }

}