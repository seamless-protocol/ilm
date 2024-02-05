// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { BaseMainnetConstants } from "./BaseMainnetConstants.sol";
import { CollateralRatio } from "../../src/types/DataTypes.sol";

struct ERC20Config {
  string name;
  string symbol;
}

struct ReserveConfig {
  address interestRateStrategyAddress;
  string aTokenName;
  string aTokenSymbol;
  string variableDebtTokenName;
  string variableDebtTokenSymbol;
  string stableDebtTokenName;
  string stableDebtTokenSymbol;
  
  uint256 ltv;
  uint256 liquidationTrashold;
  uint256 liquidationBonus;
}

struct CollateralRatioConfig {
  CollateralRatio collateralRatioTargets;
  uint256 ratioMargin;
  uint16 maxIterations;
}

struct SwapperConfig {
  uint256 swapperOffsetFactor;
  uint256 swapperOffsetDeviation;
}

struct LoopStrategyConfig {
  address underlyingTokenAddress;
  address underlyingTokenOracle;

  ERC20Config strategyERC20Config;
  ERC20Config wrappedTokenERC20Config;

  ReserveConfig wrappedTokenReserveConfig;

  CollateralRatioConfig collateralRatioConfig;

  SwapperConfig swapperConfig;
}
