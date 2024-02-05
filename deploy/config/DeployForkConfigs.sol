// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { LoopStrategyConfig, ERC20Config, ReserveConfig, CollateralRatioConfig, SwapperConfig } from "./LoopStrategyConfig.sol";
import { CollateralRatio } from "../../src/types/DataTypes.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

contract DeployForkConfigs {

  LoopStrategyConfig public cbETHconfig = LoopStrategyConfig({
    underlyingTokenAddress: 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22,
    underlyingTokenOracle: 0xd7818272B9e248357d13057AAb0B417aF31E817d,

    strategyERC20Config: ERC20Config({
      name: "CbETH/WETH Seamless ILM",
      symbol: "ilmCbETH"
    }),

    wrappedTokenERC20Config: ERC20Config({
      name: "ILM WrappedCbETH",
      symbol: "wCbETH"
    }),

    wrappedTokenReserveConfig: ReserveConfig({
      interestRateStrategyAddress: 0xcEd653F5C689eC80881b1A8b9Ab2b64DF2B963Bd,
      aTokenName: "Seamless wrapped CbETH",
      aTokenSymbol: "swCbETH",
      variableDebtTokenName: "Seamless Variable Debt wrapped CbETH",
      variableDebtTokenSymbol: "variableDebtSeamWCbETH",
      stableDebtTokenName: "Seamless Stable Debt wrapped CbETH",
      stableDebtTokenSymbol: "stableDebtSeamWCbETH",

      ltv: 90_00,
      liquidationTrashold: 92_00,
      liquidationBonus: 100_00 + 5_00
    }),

    collateralRatioConfig: CollateralRatioConfig({
      collateralRatioTargets: CollateralRatio({
        target: USDWadRayMath.usdDiv(300, 200), // 3x
        minForRebalance: USDWadRayMath.usdDiv(330, 230),  // 3.3x
        maxForRebalance: USDWadRayMath.usdDiv(270, 170),  // 2.7x
        maxForDepositRebalance: USDWadRayMath.usdDiv(299, 199), // 2.99x
        minForWithdrawRebalance: USDWadRayMath.usdDiv(301, 201)  // 3.01x 
      }),

      ratioMargin: 10 ** 4, // 0.01% ratio margin
      maxIterations: 10
    }),

    swapperConfig: SwapperConfig({
      swapperOffsetFactor: 500000, // 0.5 %
      swapperOffsetDeviation: 499000000 // 499% 
    })
  });

  LoopStrategyConfig public wstETHconfig = LoopStrategyConfig({
    underlyingTokenAddress: 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452,
    underlyingTokenOracle: 0xD815218fA8c9bd605c2b048f26cd374A752cAA76,

    strategyERC20Config: ERC20Config({
      name: "wstETH/WETH Seamless ILM",
      symbol: "ilmwstETH"
    }),

    wrappedTokenERC20Config: ERC20Config({
      name: "ILM WrappedwstETH",
      symbol: "wwstETH"
    }),

    wrappedTokenReserveConfig: ReserveConfig({
      interestRateStrategyAddress: 0xcEd653F5C689eC80881b1A8b9Ab2b64DF2B963Bd,
      aTokenName: "Seamless wrapped wstETH",
      aTokenSymbol: "swwstETH",
      variableDebtTokenName: "Seamless Variable Debt wrapped wstETH",
      variableDebtTokenSymbol: "variableDebtSeamWwstETH",
      stableDebtTokenName: "Seamless Stable Debt wrapped wstETH",
      stableDebtTokenSymbol: "stableDebtSeamWwstETH",

      ltv: 90_00,
      liquidationTrashold: 92_00,
      liquidationBonus: 100_00 + 5_00
    }),

    collateralRatioConfig: CollateralRatioConfig({
      collateralRatioTargets: CollateralRatio({
        target: USDWadRayMath.usdDiv(300, 200), // 3x
        minForRebalance: USDWadRayMath.usdDiv(301, 201),  // 3.01x
        maxForRebalance: USDWadRayMath.usdDiv(299, 199),  // 2.99x
        maxForDepositRebalance: USDWadRayMath.usdDiv(2999, 1999), // 2.999x
        minForWithdrawRebalance: USDWadRayMath.usdDiv(3001, 2001)  // 3.001x 
      }),

      ratioMargin: 10 ** 4, // 0.01% ratio margin
      maxIterations: 10
    }),

    swapperConfig: SwapperConfig({
      swapperOffsetFactor: 500000, // 0.5 %
      swapperOffsetDeviation: 499000000 // 499% 
    })
  });
}