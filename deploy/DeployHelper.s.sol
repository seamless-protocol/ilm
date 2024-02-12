// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { BaseMainnetConstants } from "./config/BaseMainnetConstants.sol";
import { LoopStrategyConfig, ERC20Config, ReserveConfig, CollateralRatioConfig } from "./config/LoopStrategyConfig.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ISwapper, Swapper } from "../src/swap/Swapper.sol";
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
    CollateralRatio,
    Step
} from "../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../src/LoopStrategy.sol";
import { WrappedTokenAdapter } from
    "../src/swap/adapter/WrappedTokenAdapter.sol";
import { AerodromeAdapter } from "../src/swap/adapter/AerodromeAdapter.sol";
import "forge-std/console.sol";

/// @title DeployHelper
/// @notice This contract contains functions to deploy and setup ILM LoopStrategy contracts
contract DeployHelper is BaseMainnetConstants {
  IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
  IPoolAddressesProvider public constant poolAddressesProvider = IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);

  /// @dev logs the contract address on the console output
  function _logAddress(string memory _name, address _address) internal view {
    console.log("%s: %s", _name, _address);
  }

  /// @dev deploys the WrappedToken contract
  /// @param initialAdmin initial DEFAULT_ADMIN role on the contract
  /// @param wrappedTokenERC20Config ERC20 configuration of the wrapped token
  /// @param underlyingToken address of the underlying token which is wrapped
  /// @return wrappedToken address of the deployed WrappedToken contract
  function _deployWrappedToken(
    address initialAdmin,
    ERC20Config memory wrappedTokenERC20Config,
    IERC20 underlyingToken
  ) internal returns (WrappedCbETH wrappedToken) {
    wrappedToken = new WrappedCbETH(
      wrappedTokenERC20Config.name, 
      wrappedTokenERC20Config.symbol, 
      underlyingToken,
      initialAdmin
    );

    _logAddress("WrappedToken", address(wrappedToken));
  }

  /// @dev set up the wrapped token on the lending pool
  /// @dev requires from the caller to have ACL_ADMIN or POOL_ADMIN role on the lending pool
  /// @param wrappedToken address of the WrappedToken contract
  /// @param wrappedTokenReserveConfig all configuration parameters for setting up the token as reserve on the lending pool
  /// @param underlyingTokenOracle address of the price oracle for the wrapped token (it's underlying token)
  function _setupWrappedToken(
    WrappedCbETH wrappedToken, 
    ReserveConfig memory wrappedTokenReserveConfig,
    address underlyingTokenOracle
  ) internal {
    ConfiguratorInputTypes.InitReserveInput[] 
    memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);

    initReserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: SEAMLESS_ATOKEN_IMPL,
      stableDebtTokenImpl: SEAMLESS_STABLE_DEBT_TOKEN_IMPL,
      variableDebtTokenImpl: SEAMLESS_VARIABLE_DEBT_TOKEN_IMPL,
      underlyingAssetDecimals: wrappedToken.decimals(),
      interestRateStrategyAddress: wrappedTokenReserveConfig.interestRateStrategyAddress,
      underlyingAsset: address(wrappedToken),
      treasury: SEAMLESS_TREASURY,
      incentivesController: SEAMLESS_INCENTIVES_CONTROLLER,
      aTokenName: wrappedTokenReserveConfig.aTokenName,
      aTokenSymbol: wrappedTokenReserveConfig.aTokenSymbol,
      variableDebtTokenName: wrappedTokenReserveConfig.variableDebtTokenName,
      variableDebtTokenSymbol: wrappedTokenReserveConfig.variableDebtTokenSymbol,
      stableDebtTokenName: wrappedTokenReserveConfig.stableDebtTokenName,
      stableDebtTokenSymbol: wrappedTokenReserveConfig.stableDebtTokenSymbol,
      params: bytes('')
    });

    IPoolConfigurator poolConfigurator = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
    
    poolConfigurator.initReserves(initReserveInputs);

    poolConfigurator.configureReserveAsCollateral(
      address(wrappedToken),
      wrappedTokenReserveConfig.ltv,
      wrappedTokenReserveConfig.liquidationTrashold,
      wrappedTokenReserveConfig.liquidationBonus
    );

    address[] memory assets = new address[](1);
    address[] memory sources = new address[](1);
    assets[0] = address(wrappedToken);
    sources[0] = underlyingTokenOracle;

    IAaveOracle(poolAddressesProvider.getPriceOracle()).setAssetSources(assets, sources);
  }

  /// @dev deploys the Swapper contract
  /// @dev requires for the caller to be the same address as `initialAdmin`
  /// @param initialAdmin initial DEFAULT_ADMIN, MANAGER_ROLE and UPGRADER_ROLE roles on the contract
  /// @param swapperOffsetDeviation maximal offset deviation of the price from the offsetFactor (in percent)
  /// @return swapper address of the deployed Swapper contract
  function _deploySwapper(
    address initialAdmin,
    uint256 swapperOffsetDeviation
  ) internal returns (Swapper swapper) {
      Swapper swapperImplementation = new Swapper();
      ERC1967Proxy swapperProxy = new ERC1967Proxy(
          address(swapperImplementation),
          abi.encodeWithSelector(
              Swapper.Swapper_init.selector, 
              initialAdmin,
              IPriceOracleGetter(poolAddressesProvider.getPriceOracle()),
              swapperOffsetDeviation
          )
      );

      swapper = Swapper(address(swapperProxy));

      swapper.grantRole(swapper.MANAGER_ROLE(), initialAdmin);
      swapper.grantRole(swapper.UPGRADER_ROLE(), initialAdmin);

      _logAddress("Swapper", address(swapper));
  }

  /// @dev deploys SwapAdapters (WrappedTokenAdapter and AerodromeAdapter) and set up those contracts
  /// @dev requires for the caller to be the same address as `initialAdmin`
  /// @param swapper address of the Swapper contract
  /// @param wrappedToken address of the WrappedToken contract
  /// @param initialAdmin initial Owner role on the contracts
  /// @return wrappedTokenAdapter address of the deployed WrappedTokenAdapter contract
  /// @return aerodromeAdapter address of the deployed AerodromeAdapter contract
  function _deploySwapAdapters(
    Swapper swapper,
    WrappedCbETH wrappedToken,
    address initialAdmin
  ) internal returns(WrappedTokenAdapter wrappedTokenAdapter, AerodromeAdapter aerodromeAdapter) {

    IERC20 underlyingToken = wrappedToken.underlying();
    
    // WrappedToken Adapter
    wrappedTokenAdapter = new WrappedTokenAdapter();
    wrappedTokenAdapter.WrappedTokenAdapter__Init(initialAdmin, address(swapper));
    wrappedTokenAdapter.setWrapper(
      underlyingToken, 
      IERC20(address(wrappedToken)), 
      IWrappedERC20PermissionedDeposit(wrappedToken)
    );

    // UnderlyingToken <-> WETH Aerodrome Adapter
    aerodromeAdapter = new AerodromeAdapter();
    aerodromeAdapter.AerodromeAdapter__Init(
        initialAdmin, AERODROME_ROUTER, AERODROME_FACTORY, address(swapper)
    );

    IRouter.Route[] memory routesUnderlyingtoWETH = new IRouter.Route[](1);
    routesUnderlyingtoWETH[0] = IRouter.Route({
        from: address(underlyingToken),
        to: address(WETH),
        stable: false,
        factory: AERODROME_FACTORY
    });

    IRouter.Route[] memory routesWETHtoUnderlying = new IRouter.Route[](1);
    routesWETHtoUnderlying[0] = IRouter.Route({
        from: address(WETH),
        to: address(underlyingToken),
        stable: false,
        factory: AERODROME_FACTORY
    });

    aerodromeAdapter.setRoutes(underlyingToken, WETH, routesUnderlyingtoWETH);
    aerodromeAdapter.setRoutes(WETH, underlyingToken, routesWETHtoUnderlying);

    _logAddress("WrappedTokenAdapter", address(wrappedTokenAdapter));
    _logAddress("AerodromeAdapter", address(aerodromeAdapter));
  }

  /// @dev set up the routes for swapping (wrappedToken <-> WETH)
  /// @dev requires for the caller to have MANAGER_ROLE on the Swapper contract
  /// @param swapper address of the Swapper contract
  /// @param wrappedToken address of the WrappedToken contract
  /// @param wrappedTokenAdapter address of the WrappedTokenAdapter contract
  /// @param aerodromeAdapter address of the AerodromeAdapter contract
  /// @param swapperOffsetFactor offsetFactor for these swapping routes
  function _setupSwapperRoutes(
    Swapper swapper,
    WrappedCbETH wrappedToken,
    WrappedTokenAdapter wrappedTokenAdapter,
    AerodromeAdapter aerodromeAdapter,
    uint256 swapperOffsetFactor
  ) internal {
      IERC20 underlyingToken = wrappedToken.underlying();

      // from wrappedToken -> WETH
      Step[] memory stepsWrappedToWETH = new Step[](2);
      stepsWrappedToWETH[0] = Step({ from: IERC20(address(wrappedToken)), to: underlyingToken, adapter: wrappedTokenAdapter });
      stepsWrappedToWETH[1] = Step({ from: underlyingToken, to: WETH, adapter: aerodromeAdapter });

      // from WETH -> wrappedToken
      Step[] memory stepsWETHtoWrapped = new Step[](2);
      stepsWETHtoWrapped[0] = Step({ from: WETH, to: underlyingToken, adapter: aerodromeAdapter });
      stepsWETHtoWrapped[1] = Step({ from: underlyingToken, to: IERC20(address(wrappedToken)), adapter: wrappedTokenAdapter });

      swapper.setRoute(IERC20(address(wrappedToken)), WETH, stepsWrappedToWETH);
      swapper.setOffsetFactor(IERC20(address(wrappedToken)), WETH, swapperOffsetFactor);

      swapper.setRoute(WETH, IERC20(address(wrappedToken)), stepsWETHtoWrapped);
      swapper.setOffsetFactor(WETH, IERC20(address(wrappedToken)), swapperOffsetFactor);
  }

  /// @dev deploys LoopStrategy contract
  /// @dev requires for the caller to be the same address as `initialAdmin`
  /// @param wrappedToken address of the WrappedToken contract
  /// @param initialAdmin initial DEFAULT_ADMIN, MANAGER_ROLE, UPGRADER_ROLE and PAUSER_ROLE roles on the contract
  /// @param swapper address of the Swapper contract
  /// @param config configuration paramteres for the LoopStrategy contract
  /// @return strategy address of the deployed LoopStrategy contract
  function _deployLoopStrategy(
    WrappedCbETH wrappedToken,
    address initialAdmin,
    ISwapper swapper,
    LoopStrategyConfig memory config
  ) internal returns (LoopStrategy strategy) {
      StrategyAssets memory strategyAssets = StrategyAssets({
          underlying: IERC20(config.underlyingTokenAddress),
          collateral: IERC20(address(wrappedToken)),
          debt: WETH
      });

      LoopStrategy strategyImplementation = new LoopStrategy();

      ERC1967Proxy strategyProxy = new ERC1967Proxy(
          address(strategyImplementation),
          abi.encodeWithSelector(
              LoopStrategy.LoopStrategy_init.selector,
              config.strategyERC20Config.name,
              config.strategyERC20Config.symbol,
              initialAdmin,
              strategyAssets,
              config.collateralRatioConfig.collateralRatioTargets,
              poolAddressesProvider,
              IPriceOracleGetter(poolAddressesProvider.getPriceOracle()),
              swapper,
              config.collateralRatioConfig.ratioMargin,
              config.collateralRatioConfig.maxIterations
          )
      );
      strategy = LoopStrategy(address(strategyProxy));
      
      strategy.grantRole(strategy.PAUSER_ROLE(), initialAdmin);
      strategy.grantRole(strategy.MANAGER_ROLE(), initialAdmin);
      strategy.grantRole(strategy.UPGRADER_ROLE(), initialAdmin);

      _logAddress("Strategy", address(strategy));
  }

  /// @dev set deposit permissions to the LoopStrategy and WrappedTokenAdapter contracts
  /// @dev requires caller to have MANAGER_ROLE on the WrappedToken contract
  /// @param wrappedToken address of the WrappedTokenContract
  /// @param wrappedTokenAdapter address of the WrappedTokenAdapter contract
  /// @param strategy address of the LoopStrategy contract
  function _setupWrappedTokenRoles(
    WrappedCbETH wrappedToken,
    address wrappedTokenAdapter,
    address strategy
  ) internal {
    wrappedToken.setDepositPermission(strategy, true);
    wrappedToken.setDepositPermission(wrappedTokenAdapter, true);
  }

  /// @dev set STRATEGY_ROLE to the LoopStrategy contract
  /// @dev requires caller to have MANAGER_ROLE on the Swapper contract
  /// @param swapper address of the Swapper contract
  /// @param strategy address of the LoopStrategy contract
  function _setupSwapperRoles(
    Swapper swapper,
    LoopStrategy strategy
  ) internal {
    swapper.grantRole(swapper.STRATEGY_ROLE(), address(strategy));
  }
}