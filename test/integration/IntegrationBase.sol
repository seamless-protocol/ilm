// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { IACLManager } from "@aave/contracts/interfaces/IACLManager.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { DeployHelper } from "../../deploy/DeployHelper.s.sol";
import { LoopStrategyConfig } from "../../deploy/config/LoopStrategyConfig.sol";
import { DeployForkConfigs } from "../../deploy/config/DeployForkConfigs.sol";
import { Swapper } from "../../src/swap/Swapper.sol";
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
    Swapper public swapper;
    WrappedTokenAdapter public wrappedTokenAdapter;
    AerodromeAdapter public aerodromeAdapter;
    LoopStrategy public strategy;

    function setUp() public virtual {
        vm.createSelectFork(BASE_RPC_URL);

        // _setDeployer(testDeployer.privateKey);

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
        _setupWETHborrowCap();

        swapper = _deploySwapper(
            testDeployer.addr,
            config.swapperConfig.swapperOffsetDeviation
        );
        (wrappedTokenAdapter, aerodromeAdapter) = 
            _deploySwapAdapters(
                swapper,
                wrappedToken,
                testDeployer.addr,
                config.underlyingTokenAddress
            );
        _setupSwapperRoutes(
            swapper,
            wrappedToken,
            wrappedTokenAdapter,
            aerodromeAdapter,
            config.underlyingTokenAddress,
            config.swapperConfig.swapperOffsetFactor
        );

        strategy = _deployLoopStrategy(
            wrappedToken,
            testDeployer.addr,
            swapper,
            config
        );

        _setupWrappedTokenRoles(wrappedToken, wrappedTokenAdapter, strategy);
        _setupWrappedSwapperRoles(swapper, strategy);
        vm.stopPrank();
    }
}
