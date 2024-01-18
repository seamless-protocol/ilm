// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "forge-std/script.sol";
import { TenderlyForkConfig } from "./config/TenderlyForkConfig.sol";
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

/// @title DeployTenderlyFork
/// @notice Deploys and setups all contracts needed for ILM LoopStrategy, when collateral is CbETH and borrow asset is WETH
/// @notice Made for using on fork of the Base Mainnet.
/// @notice Assumes that deployer has roles for the Seamless pool configuration (ACL_ADMIN and POOL_ADMIN)
/// @notice To obtain roles on the fork, run the simulation on Tenderly UI.  
/// @dev deploy with the command: 
/// @dev forge script ./deploy/DeployTenderlyFork.s.sol --rpc-url ${TENDERLY_FORK_RPC} --broadcast --slow --delay 20 --force
contract DeployTenderlyFork is Script, TenderlyForkConfig {
  IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);
  IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
  IPoolAddressesProvider public constant poolAddressesProvider = IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);

  uint256 deployerPrivateKey;
  address deployerAddress;

  WrappedCbETH public wrappedCbETH;
  Swapper public swapper;
  WrappedTokenAdapter public wrappedTokenAdapter;
  AerodromeAdapter public aerodromeAdapter;
  LoopStrategy public strategy;

  function run() public {
    deployerPrivateKey = vm.envUint("DEPLOYER_PK");
    deployerAddress = vm.addr(deployerPrivateKey);

    _deployWrappedCbETH();
    _setupWrappedCbETH();
    _setupWETHborrowCap();

    _deploySwapper();
    _deploySwapAdapters();
    _setupSwapperRoutes();

    _deployLoopStrategy();

    _setupRoles();
  }

  function _logAddress(string memory _name, address _address) internal view {
    console.log("%s: %s", _name, _address);
  }

  function _deployWrappedCbETH() internal {
    vm.startBroadcast(deployerPrivateKey);
    wrappedCbETH = new WrappedCbETH("WrappedCbETH", "wCbETH", CbETH, deployerAddress);
    vm.stopBroadcast();

    _logAddress("WrappedCbETH", address(wrappedCbETH));
  }

  function _setupWrappedCbETH() internal {
    ConfiguratorInputTypes.InitReserveInput[] 
    memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);

    initReserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: SEAMLESS_ATOKEN_IMPL,
      stableDebtTokenImpl: SEAMLESS_STABLE_DEBT_TOKEN_IMPL,
      variableDebtTokenImpl: SEAMLESS_VARIABLE_DEBT_TOKEN_IMPL,
      underlyingAssetDecimals: 18,
      interestRateStrategyAddress: SEAMLESS_CBETH_INTEREST_RATE_STRATEGY_ADDRESS,
      underlyingAsset: address(wrappedCbETH),
      treasury: SEAMLESS_TREASURY,
      incentivesController: SEAMLESS_INCENTIVES_CONTROLLER,
      aTokenName: wrappedCbETH_aTokenName,
      aTokenSymbol: wrappedCbETH_aTokenSymbol,
      variableDebtTokenName: wrappedCbETH_variableDebtTokenName,
      variableDebtTokenSymbol: wrappedCbETH_variableDebtTokenSymbol,
      stableDebtTokenName: wrappedCbETH_stableDebtTokenName,
      stableDebtTokenSymbol: wrappedCbETH_stableDebtTokenSymbol,
      params: bytes('')
    });

    vm.startBroadcast(deployerPrivateKey);

    IPoolConfigurator poolConfigurator = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
    
    poolConfigurator.initReserves(initReserveInputs);

    poolConfigurator.configureReserveAsCollateral(
      address(wrappedCbETH),
      wrappedCbETH_LTV,
      wrappedCbETH_LiquidationTrashold,
      wrappedCbETH_LiquidationBonus
    );

    address[] memory assets = new address[](1);
    address[] memory sources = new address[](1);
    assets[0] = address(wrappedCbETH);
    sources[0] = CHAINLINK_CBETH_USD_ORACLE;

    IAaveOracle(poolAddressesProvider.getPriceOracle()).setAssetSources(assets, sources);
    vm.stopBroadcast();
  }

  function _setupWETHborrowCap() internal {
    vm.startBroadcast(deployerPrivateKey);
    IPoolConfigurator(poolAddressesProvider.getPoolConfigurator()).setBorrowCap(address(WETH), 1000000);
    vm.stopBroadcast();
  }

  function _deploySwapper() internal {
      vm.startBroadcast(deployerPrivateKey);
      Swapper swapperImplementation = new Swapper();
      ERC1967Proxy swapperProxy = new ERC1967Proxy(
          address(swapperImplementation),
          abi.encodeWithSelector(
              Swapper.Swapper_init.selector, 
              deployerAddress
          )
      );

      swapper = Swapper(address(swapperProxy));

      swapper.grantRole(swapper.MANAGER_ROLE(), deployerAddress);
      swapper.grantRole(swapper.UPGRADER_ROLE(), deployerAddress);
      vm.stopBroadcast();

      _logAddress("Swapper", address(swapper));
  }

  function _deploySwapAdapters() internal {
    vm.startBroadcast(deployerPrivateKey);
    
    // WrappedCbETH Adapter
    wrappedTokenAdapter = new WrappedTokenAdapter();
    wrappedTokenAdapter.WrappedTokenAdapter__Init(deployerAddress);
    wrappedTokenAdapter.setSwapper(address(swapper));
    wrappedTokenAdapter.setWrapper(
      CbETH, 
      IERC20(address(wrappedCbETH)), 
      IWrappedERC20PermissionedDeposit(wrappedCbETH)
    );


    // CbETH <-> WETH Aerodrome Adapter
    aerodromeAdapter = new AerodromeAdapter();
    aerodromeAdapter.AerodromeAdapter__Init(
        deployerAddress, AERODROME_ROUTER, AERODROME_FACTORY
    );
    aerodromeAdapter.setSwapper(address(swapper));

    IRouter.Route[] memory routesCbETHtoWETH = new IRouter.Route[](1);
    routesCbETHtoWETH[0] = IRouter.Route({
        from: address(CbETH),
        to: address(WETH),
        stable: false,
        factory: AERODROME_FACTORY
    });

    IRouter.Route[] memory routesWETHtoCbETH= new IRouter.Route[](1);
    routesWETHtoCbETH[0] = IRouter.Route({
        from: address(WETH),
        to: address(CbETH),
        stable: false,
        factory: AERODROME_FACTORY
    });

    aerodromeAdapter.setRoutes(CbETH, WETH, routesCbETHtoWETH);
    aerodromeAdapter.setRoutes(WETH, CbETH, routesWETHtoCbETH);
    vm.stopBroadcast();

    _logAddress("WrappedTokenAdapter", address(wrappedTokenAdapter));
    _logAddress("AerodromeAdapter", address(aerodromeAdapter));
  }


  function _setupSwapperRoutes() internal {
      // from wrappedCbETH -> WETH
      Step[] memory stepsWrappedToWETH = new Step[](2);
      stepsWrappedToWETH[0] = Step({ from: IERC20(address(wrappedCbETH)), to: CbETH, adapter: wrappedTokenAdapter });
      stepsWrappedToWETH[1] = Step({ from: CbETH, to: WETH, adapter: aerodromeAdapter });

      // from WETH -> wrappedCbETH
      Step[] memory stepsWETHtoWrapped = new Step[](2);
      stepsWETHtoWrapped[0] = Step({ from: WETH, to: CbETH, adapter: aerodromeAdapter });
      stepsWETHtoWrapped[1] = Step({ from: CbETH, to: IERC20(address(wrappedCbETH)), adapter: wrappedTokenAdapter });

      vm.startBroadcast(deployerPrivateKey);
      swapper.setRoute(IERC20(address(wrappedCbETH)), WETH, stepsWrappedToWETH);
      swapper.setRoute(WETH, IERC20(address(wrappedCbETH)), stepsWETHtoWrapped);
      vm.stopBroadcast();
  }

  function _deployLoopStrategy() internal {
      StrategyAssets memory strategyAssets = StrategyAssets({
          underlying: CbETH,
          collateral: IERC20(address(wrappedCbETH)),
          debt: WETH
      });

      vm.startBroadcast(deployerPrivateKey);
      LoopStrategy strategyImplementation = new LoopStrategy();

      ERC1967Proxy strategyProxy = new ERC1967Proxy(
          address(strategyImplementation),
          abi.encodeWithSelector(
              LoopStrategy.LoopStrategy_init.selector,
              STRATEGY_ERC20_NAME,
              STRATEGY_ERC20_SYMBOL,
              deployerAddress,
              strategyAssets,
              collateralRatioTargets,
              poolAddressesProvider,
              IPriceOracleGetter(poolAddressesProvider.getPriceOracle()),
              swapper,
              ratioMargin,
              maxIterations
          )
      );
      strategy = LoopStrategy(address(strategyProxy));
      
      strategy.grantRole(strategy.PAUSER_ROLE(), deployerAddress);
      strategy.grantRole(strategy.MANAGER_ROLE(), deployerAddress);
      strategy.grantRole(strategy.UPGRADER_ROLE(), deployerAddress);
      vm.stopBroadcast();

      _logAddress("Strategy", address(strategy));
  }

  function _setupRoles() internal {
    vm.startBroadcast(deployerPrivateKey);
    wrappedCbETH.setDepositPermission(address(strategy), true);
    wrappedCbETH.setDepositPermission(address(wrappedTokenAdapter), true);

    swapper.grantRole(swapper.STRATEGY_ROLE(), address(strategy));
    vm.stopBroadcast();
  }
}