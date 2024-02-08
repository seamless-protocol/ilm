// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { IACLManager } from "@aave/contracts/interfaces/IACLManager.sol";
import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { DefaultReserveInterestRateStrategy } from "@aave/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { DeployHelper } from "../../deploy/DeployHelper.s.sol";
import { LoopStrategyConfig } from "../../deploy/config/LoopStrategyConfig.sol";
import { DeployForkConfigs } from "../../deploy/config/DeployForkConfigs.sol";
import { ISwapper, Swapper } from "../../src/swap/Swapper.sol";
import {
    WrappedCbETH,
    IWrappedERC20PermissionedDeposit
} from "../../src/tokens/WrappedCbETH.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { WrappedTokenAdapter } from
    "../../src/swap/adapter/WrappedTokenAdapter.sol";
import { AerodromeAdapter } from "../../src/swap/adapter/AerodromeAdapter.sol";
import { VmSafe } from "forge-std/Vm.sol";

/// @notice Setup contract for the integration tests
/// @notice deploys all related contracts on the fork, and setup lending pool parameters
contract IntegrationBase is Test, DeployHelper, DeployForkConfigs {

    string internal BASE_RPC_URL = vm.envString("BASE_MAINNET_RPC_URL");

    VmSafe.Wallet public testDeployer = vm.createWallet("deployer");
    
    LoopStrategyConfig public config;
    IERC20 public underlyingToken;

    WrappedCbETH public wrappedToken;
    ISwapper public swapper;
    WrappedTokenAdapter public wrappedTokenAdapter;
    AerodromeAdapter public aerodromeAdapter;
    LoopStrategy public strategy;

    function setUp() public virtual {
        vm.createSelectFork(BASE_RPC_URL, 10131522);

        address aclAdmin = poolAddressesProvider.getACLAdmin();
        vm.startPrank(aclAdmin);
        IACLManager(poolAddressesProvider.getACLManager()).addPoolAdmin(
            testDeployer.addr
        );
        poolAddressesProvider.setACLAdmin(testDeployer.addr);
        vm.stopPrank();

        config = cbETHconfig;

        underlyingToken = IERC20(config.underlyingTokenAddress);
        
        vm.startPrank(testDeployer.addr);
        wrappedToken = _deployWrappedToken(
            testDeployer.addr,
            config.wrappedTokenERC20Config,
            underlyingToken
        );
        _setupWrappedToken(
            wrappedToken,
            config.wrappedTokenReserveConfig,
            config.underlyingTokenOracle
        );

        IPoolConfigurator(poolAddressesProvider.getPoolConfigurator()).setBorrowCap(address(WETH), 1000000);

        swapper = _deploySwapper(
            testDeployer.addr,
            config.swapperConfig.swapperOffsetDeviation
        );
        (wrappedTokenAdapter, aerodromeAdapter) = 
            _deploySwapAdapters(
                Swapper(address(swapper)),
                wrappedToken,
                testDeployer.addr
            );
        _setupSwapperRoutes(
            Swapper(address(swapper)),
            wrappedToken,
            wrappedTokenAdapter,
            aerodromeAdapter,
            config.swapperConfig.swapperOffsetFactor
        );

        strategy = _deployLoopStrategy(
            wrappedToken,
            testDeployer.addr,
            swapper,
            config
        );

        _setupWrappedTokenRoles(wrappedToken, address(wrappedTokenAdapter), address(strategy));
        _setupSwapperRoles(Swapper(address(swapper)), strategy);

        vm.stopPrank();
    }

    /// @dev deploys and sets the interest strategy with the (almost) flat borrow rate
    /// @param borrowRate new interest rate
    function _changeBorrowInterestRate(uint256 borrowRate) internal {
        vm.startPrank(testDeployer.addr);

        DefaultReserveInterestRateStrategy interestRateStrategy = new DefaultReserveInterestRateStrategy(
            poolAddressesProvider,
            0.5 * 1e27,               
            borrowRate,               
            0.0000001 * 1e27,           
            0.0000001 * 1e27,               
            0.0000001 * 1e27,             
            0.0000001 * 1e27,             
            0.0000001 * 1e27,           
            0.0000001 * 1e27,             
            0.0000001 * 1e27          
        );

        IPoolConfigurator(poolAddressesProvider.getPoolConfigurator())
            .setReserveInterestRateStrategyAddress(address(WETH), address(interestRateStrategy));

         vm.stopPrank();
    }
}
