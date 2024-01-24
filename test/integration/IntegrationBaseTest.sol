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
import { IntegrationBase } from "./IntegrationBase.sol";
import { IRouter } from "../../src/vendor/aerodrome/IRouter.sol";
import "forge-std/console.sol";

/// @notice Test confirming deployment is done correctly and we can deposit and redeem funds
contract IntegrationBaseTest is IntegrationBase {
    using stdStorage for StdStorage;

    /// @dev test confirming deployment is done correctly and we can deposit and redeem funds
    function test_integrationBaseTest() public {
      address user = makeAddr("user");

      uint256 amount = 1 ether;
      console.log(amount);

      vm.startPrank(user);
      deal(address(CbETH), user, amount);
      CbETH.approve(address(strategy), amount);

      uint256 shares = strategy.deposit(amount, user);

      strategy.redeem(shares / 2, user, user);

      vm.stopPrank();
    }
}
