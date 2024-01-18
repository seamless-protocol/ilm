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
import "forge-std/console.sol";

contract PreviewAccuracyTest is IntegrationBase {
    using stdStorage for StdStorage;

    function test_previewDepositAccuracy() public {
        uint256 seed = 1;

        uint256 maxDiff = 0;
        uint256 maxPercentDiff = 0;

        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.addr(i);
            seed = uint256(keccak256(abi.encode(seed)));

            uint256 amount = bound(seed, 0.1 ether, 5 ether);
            console.log(amount);

            vm.startPrank(user);
            deal(address(CbETH), user, amount);
            CbETH.approve(address(strategy), amount);

            uint256 previewDeposit = strategy.previewDeposit(amount);

            uint256 shares = strategy.deposit(amount, user);

            console.log("shares", shares);
            console.log("previewDeposit", previewDeposit);

            if (previewDeposit > shares) {
                maxDiff = Math.max(maxDiff, previewDeposit - shares);
                maxPercentDiff = Math.max(
                    maxPercentDiff, USDWadRayMath.wadDiv(previewDeposit, shares)
                );
            }

            vm.stopPrank();
        }

        console.log("maxDiff", maxDiff);
        console.log("maxPercentDiff", maxPercentDiff);
    }
}
