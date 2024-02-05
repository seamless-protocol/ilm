// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { IACLManager } from "@aave/contracts/interfaces/IACLManager.sol";
import { DeployForkScript } from "../../deploy/DeployFork.s.sol";
import { VmSafe } from "forge-std/Vm.sol";

/// @notice Setup contract for the integration tests
/// @notice deploys all related contracts on the fork, and setup lending pool parameters
contract IntegrationBase is Test, DeployForkScript {
    string internal BASE_RPC_URL = vm.envString("BASE_MAINNET_RPC_URL");

    VmSafe.Wallet public testDeployer = vm.createWallet("deployer");

    function setUp() public virtual {
        vm.createSelectFork(BASE_RPC_URL);

        _setDeployer(testDeployer.privateKey);

        address aclAdmin = poolAddressesProvider.getACLAdmin();
        vm.startPrank(aclAdmin);
        IACLManager(poolAddressesProvider.getACLManager()).addPoolAdmin(
            testDeployer.addr
        );
        poolAddressesProvider.setACLAdmin(testDeployer.addr);
        vm.stopPrank();

        _deployWrappedCbETH();
        _setupWrappedCbETH();
        _setupWETHborrowCap();

        _deploySwapper();
        _deploySwapAdapters();
        _setupSwapperRoutes();

        _deployLoopStrategy();

        _setupRoles();
    }
}
