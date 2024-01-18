// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { IACLManager } from "@aave/contracts/interfaces/IACLManager.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "../unit/LoopStrategy.t.sol";
import { DeployTenderlyFork } from "../../deploy/DeployTenderlyFork.s.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import "forge-std/console.sol";

/// @notice Setup contract for the integration tests
/// @notice deploys all related contracts on the fork, and setup lending pool parameters
contract IntegrationBase is Test, DeployTenderlyFork {
    using stdStorage for StdStorage;

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
