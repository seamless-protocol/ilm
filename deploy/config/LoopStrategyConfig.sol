// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { BaseMainnetConstants } from "./BaseMainnetConstants.sol";
import { CollateralRatio } from "../../src/types/DataTypes.sol";

/// @dev configuration for the ERC20 token
struct ERC20Config {
  string name;
  string symbol;
}

/// @dev configuration for setting up token as reserve on the lending pool
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

/// @dev configuration of the collateral ratio targets for the strategy
struct CollateralRatioConfig {
  CollateralRatio collateralRatioTargets;
  uint256 ratioMargin;
  uint16 maxIterations;
}

/// @dev configuration of the offset factor and max offset deviation for the Swapepr contract
struct SwapperConfig {
  uint256 swapperOffsetFactor;
  uint256 swapperOffsetDeviation;
}

/// @dev configuration  for the LoopStrategy contract
struct LoopStrategyConfig {
  address underlyingTokenAddress;
  address underlyingTokenOracle;

  ERC20Config strategyERC20Config;
  ERC20Config wrappedTokenERC20Config;

  ReserveConfig wrappedTokenReserveConfig;

  CollateralRatioConfig collateralRatioConfig;

  SwapperConfig swapperConfig;
}
