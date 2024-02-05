// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { BaseMainnetConstants } from "./config/BaseMainnetConstants.sol";
import { LoopStrategyConfig, ERC20Config, ReserveConfig, CollateralRatioConfig } from "./config/LoopStrategyConfig.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Swapper } from "../src/swap/Swapper.sol";
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

/// @title DeployFork
/// @notice Deploys and setups all contracts needed for ILM LoopStrategy, when collateral is CbETH and borrow asset is WETH
/// @notice Made for using on fork of the Base Mainnet.
/// @notice Assumes that deployer has roles for the Seamless pool configuration (ACL_ADMIN and POOL_ADMIN)
/// @notice To obtain roles on the fork, run the simulation on Tenderly UI.  
/// @dev deploy with the command: 
/// @dev forge script ./deploy/DeployFork.s.sol --rpc-url ${FORK_RPC} --broadcast --slow --delay 20 --force
contract DeployHelper is BaseMainnetConstants {
  IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
  IPoolAddressesProvider public constant poolAddressesProvider = IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);

  // uint256 deployerPrivateKey;
  // address deployerAddress;

  // LoopStrategyConfig public config;

  // WrappedCbETH public wrappedCbETH;
  // Swapper public swapper;
  // WrappedTokenAdapter public wrappedTokenAdapter;
  // AerodromeAdapter public aerodromeAdapter;
  // LoopStrategy public strategy;

  // function _setDeployer(uint256 _deployerPrivateKey) internal {
  //   deployerPrivateKey = _deployerPrivateKey; 
  //   deployerAddress = vm.addr(deployerPrivateKey);
  // }

  function _logAddress(string memory _name, address _address) internal view {
    console.log("%s: %s", _name, _address);
  }

  function _deployWrappedToken(
    address initialAdmin,
    ERC20Config memory wrappedTokenERC20Config,
    IERC20 underlyingToken
  ) internal returns (WrappedCbETH wrappedToken) {
    // vm.startBroadcast(deployerPrivateKey);
    wrappedToken = new WrappedCbETH(
      wrappedTokenERC20Config.name, 
      wrappedTokenERC20Config.symbol, 
      underlyingToken,
      initialAdmin
    );
    // vm.stopBroadcast();

    _logAddress("WrappedToken", address(wrappedToken));
  }

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
      underlyingAssetDecimals: 18,
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

    // vm.startBroadcast(deployerPrivateKey);

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
    // vm.stopBroadcast();
  }

  function _setupWETHborrowCap() internal {
    // vm.startBroadcast(deployerPrivateKey);
    IPoolConfigurator(poolAddressesProvider.getPoolConfigurator()).setBorrowCap(address(WETH), 1000000);
    // vm.stopBroadcast();
  }

  function _deploySwapper(
    address initialAdmin,
    uint256 swapperOffsetDeviation
  ) internal returns (Swapper swapper) {
      // vm.startBroadcast(deployerPrivateKey);
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
      // vm.stopBroadcast();

      _logAddress("Swapper", address(swapper));
  }

  function _deploySwapAdapters(
    Swapper swapper,
    WrappedCbETH wrappedToken,
    address initialAdmin,
    address underlyingTokenAddress
  ) internal returns(WrappedTokenAdapter wrappedTokenAdapter, AerodromeAdapter aerodromeAdapter) {
    // vm.startBroadcast(deployerPrivateKey);

    IERC20 underlyingToken = IERC20(underlyingTokenAddress);
    
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
        from: underlyingTokenAddress,
        to: address(WETH),
        stable: false,
        factory: AERODROME_FACTORY
    });

    IRouter.Route[] memory routesWETHtoUnderlying = new IRouter.Route[](1);
    routesWETHtoUnderlying[0] = IRouter.Route({
        from: address(WETH),
        to: underlyingTokenAddress,
        stable: false,
        factory: AERODROME_FACTORY
    });

    aerodromeAdapter.setRoutes(underlyingToken, WETH, routesUnderlyingtoWETH);
    aerodromeAdapter.setRoutes(WETH, underlyingToken, routesWETHtoUnderlying);
    // vm.stopBroadcast();

    _logAddress("WrappedTokenAdapter", address(wrappedTokenAdapter));
    _logAddress("AerodromeAdapter", address(aerodromeAdapter));
  }


  function _setupSwapperRoutes(
    Swapper swapper,
    WrappedCbETH wrappedToken,
    WrappedTokenAdapter wrappedTokenAdapter,
    AerodromeAdapter aerodromeAdapter,
    address underlyingTokenAddress,
    uint256 swapperOffsetFactor
  ) internal {
      IERC20 underlyingToken = IERC20(underlyingTokenAddress);

      // from wrappedToken -> WETH
      Step[] memory stepsWrappedToWETH = new Step[](2);
      stepsWrappedToWETH[0] = Step({ from: IERC20(address(wrappedToken)), to: underlyingToken, adapter: wrappedTokenAdapter });
      stepsWrappedToWETH[1] = Step({ from: underlyingToken, to: WETH, adapter: aerodromeAdapter });

      // from WETH -> wrappedToken
      Step[] memory stepsWETHtoWrapped = new Step[](2);
      stepsWETHtoWrapped[0] = Step({ from: WETH, to: underlyingToken, adapter: aerodromeAdapter });
      stepsWETHtoWrapped[1] = Step({ from: underlyingToken, to: IERC20(address(wrappedToken)), adapter: wrappedTokenAdapter });

      // vm.startBroadcast(deployerPrivateKey);
      swapper.setRoute(IERC20(address(wrappedToken)), WETH, stepsWrappedToWETH);
      swapper.setOffsetFactor(IERC20(address(wrappedToken)), WETH, swapperOffsetFactor);

      swapper.setRoute(WETH, IERC20(address(wrappedToken)), stepsWETHtoWrapped);
      swapper.setOffsetFactor(WETH, IERC20(address(wrappedToken)), swapperOffsetFactor);
      // vm.stopBroadcast();
  }

  function _deployLoopStrategy(
    WrappedCbETH wrappedToken,
    address initialAdmin,
    Swapper swapper,
    LoopStrategyConfig memory config
  ) internal returns (LoopStrategy strategy) {
      StrategyAssets memory strategyAssets = StrategyAssets({
          underlying: IERC20(config.underlyingTokenAddress),
          collateral: IERC20(address(wrappedToken)),
          debt: WETH
      });

      // vm.startBroadcast(deployerPrivateKey);
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
      // vm.stopBroadcast();

      _logAddress("Strategy", address(strategy));
  }

  function _setupWrappedTokenRoles(
    WrappedCbETH wrappedToken,
    WrappedTokenAdapter wrappedTokenAdapter,
    LoopStrategy strategy
  ) internal {
    // vm.startBroadcast(deployerPrivateKey);
    wrappedToken.setDepositPermission(address(strategy), true);
    wrappedToken.setDepositPermission(address(wrappedTokenAdapter), true);
    // vm.stopBroadcast();
  }

  function _setupWrappedSwapperRoles(
    Swapper swapper,
    LoopStrategy strategy
  ) internal {
    // vm.startBroadcast(deployerPrivateKey);
    swapper.grantRole(swapper.STRATEGY_ROLE(), address(strategy));
    // vm.stopBroadcast();
  }
}