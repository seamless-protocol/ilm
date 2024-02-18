// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import { BaseForkTest } from "../BaseForkTest.t.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { WrappedERC20PermissionedDeposit } from
    "../../src/tokens/WrappedERC20PermissionedDeposit.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "../unit/LoopStrategy.t.sol";

/// @notice Scenario tests for the LoopStrategy
/// @notice gsheets models reference: https://docs.google.com/spreadsheets/d/1d9L_uX4qYCo6i7jxQXZjI55ogBsNhNI2q8jbdJ2P6g0
contract LoopStrategyScenariosTest is LoopStrategyTest {
    using USDWadRayMath for uint256;

    uint256 constant USD_DELTA = 0.0001 * 1e8;
    uint256 constant ETH_DELTA = 0.0001 ether;

    /// @dev setting up the starting parameters for scenarios
    /// @dev it assums CbETH as collateral asset and USDbC as borrowing asset
    /// @param startCollateral total collateral currently supplied to the lending pool from the strategy
    /// @param startLeverage current leverage ratio (2 decimals)
    /// @param targetLeverage target leverage ratio for the pool (2 decimals)
    /// @param startShares amount of starting shares (18 decimals)
    function _setupScenario(
        uint256 startCollateral,
        uint256 startLeverage,
        uint256 targetLeverage,
        uint256 startShares
    ) internal {
        uint256 targetRatio =
            USDWadRayMath.usdDiv(targetLeverage, targetLeverage - 100);
        uint256 rebalanceDiff = PercentageMath.percentMul(targetRatio, 300);

        collateralRatioTargets = CollateralRatio({
            target: targetRatio,
            minForRebalance: targetRatio - rebalanceDiff,
            maxForRebalance: targetRatio + rebalanceDiff,
            maxForDepositRebalance: targetRatio,
            minForWithdrawRebalance: targetRatio
        });
        strategy.setCollateralRatioTargets(collateralRatioTargets);

        // price at block number: 5950437
        uint256 CbETHprice = 1798_87843722;
        _changePrice(CbETH, CbETHprice);
        _changePrice(USDbC, 1_00000000);
        swapOffset = 5e6;
        SwapperMock(address(swapper)).setOffsets(swapOffset, swapOffset);
        SwapperMock(address(swapper)).setRealOffsets(swapOffset, swapOffset);

        _changeLtv(CbETH, 80_00, 85_00, 105_00);

        uint256 startDebtUSD = (
            startCollateral * CbETHprice * (startLeverage - 100)
        ) / (startLeverage * 1e18);
        uint256 startDebt = startDebtUSD / 1e2;

        vm.startPrank(address(strategy));
        deal(address(CbETH), address(strategy), startCollateral);
        lendingPool.pool.supply(
            address(CbETH), startCollateral, address(strategy), 0
        );
        lendingPool.pool.borrow(
            address(USDbC),
            startDebt,
            lendingPool.interestRateMode,
            0,
            address(strategy)
        );
        deal(address(strategy), address(strategy), startShares, true);
        vm.stopPrank();
    }

    /// @notice deposit when pool is already at the target leverage ratio
    /// @notice scenario 1 in the gsheet
    function test_scenario_1_depositWhenPoolAtTarget() public {
        _setupScenario(1 ether, 300, 300, 1000 ether);

        assertEq(strategy.collateral(), 1798_87843722);
        assertEq(strategy.debt(), 1199_25229100);
        assertEq(strategy.currentCollateralRatio(), 1_50000000);
        assertEq(strategy.totalAssets(), 333333333600166261);
        assertEq(strategy.totalSupply(), 1000 ether);

        _depositFor(alice, 0.1 ether);

        // we are doing approximate equals because there is different losing of precision between gsheets model and solidity calculations
        assertApproxEqAbs(strategy.collateral(), 2289_48164700, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 1526_32109800, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 1_50000000, USD_DELTA
        );
        assertApproxEqAbs(strategy.totalAssets(), 0.4242 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.totalSupply(), 1272.7273 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.balanceOf(alice), 272.7273 ether, ETH_DELTA);
    }

    /// @notice deposit when pool should rebalance before processing the new deposit
    /// @notice scneraio 2 in the gsheet
    function test_scenario_2_depositWhenPoolBelowMinForRebalance() public {
        _setupScenario(1 ether, 400, 350, 1000 ether);

        assertEq(strategy.collateral(), 1798_87843722);
        assertEq(strategy.debt(), 1349_15882700);
        assertEq(strategy.currentCollateralRatio(), 1_33333333);
        assertEq(strategy.totalAssets(), 250000000508650268);
        assertEq(strategy.totalSupply(), 1000 ether);

        _depositFor(alice, 0.01 ether);

        assertApproxEqAbs(strategy.collateral(), 1582_28620500, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 1130_20443200, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 1_40000000, USD_DELTA
        );
        assertApproxEqAbs(strategy.totalAssets(), 0.2513 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.totalSupply(), 1036.6667 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.balanceOf(alice), 36.6667 ether, ETH_DELTA);
    }

    /// @notice withdrawal when pool is already at the target leverage ratio
    /// @notice scneraio 3 in the gsheet
    function test_scenario_3_withdrawWhenPoolAtTarget() public {
        _setupScenario(100 ether, 300, 300, 1000 ether);
        deal(address(strategy), alice, 30 ether, false);

        assertEq(strategy.collateral(), 179887_84372200);
        assertEq(strategy.debt(), 119925_22914800);
        assertEq(strategy.currentCollateralRatio(), 1_50000000);
        assertEq(strategy.totalAssets(), 33333333333333333333);
        assertEq(strategy.totalSupply(), 1000 ether);
        assertEq(strategy.balanceOf(alice), 30 ether);

        uint256 balanceBefore = CbETH.balanceOf(alice);
        vm.startPrank(alice);
        strategy.redeem(30 ether, alice, alice);
        vm.stopPrank();
        uint256 withdrawnAmount = CbETH.balanceOf(alice) - balanceBefore;

        assertApproxEqAbs(strategy.collateral(), 174491_20841034, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 116327_47227356, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 1_50000000, USD_DELTA
        );
        assertApproxEqAbs(strategy.totalAssets(), 32.3333 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.totalSupply(), 970 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.balanceOf(alice), 0 ether, ETH_DELTA);
        assertApproxEqAbs(withdrawnAmount, 0.8947368421 ether, ETH_DELTA);
    }

    /// @notice wirhdraw when pool should rebalance before processing the new withdraw
    /// @notice scneraio 4 in the gsheet
    function test_scenario_4_withdrawWhenPoolBelowMinForRebalance() public {
        _setupScenario(100 ether, 400, 300, 1000 ether);
        deal(address(strategy), alice, 30 ether, false);

        assertEq(strategy.collateral(), 179887_84372200);
        assertEq(strategy.debt(), 134915_88279100);
        assertEq(strategy.currentCollateralRatio(), 1_33333333);
        assertEq(strategy.totalAssets(), 25000000000277950966);
        assertEq(strategy.totalSupply(), 1000 ether);
        assertEq(strategy.balanceOf(alice), 30 ether);

        uint256 balanceBefore = CbETH.balanceOf(alice);
        vm.startPrank(alice);
        strategy.redeem(30 ether, alice, alice);
        vm.stopPrank();
        uint256 withdrawnAmount = CbETH.balanceOf(alice) - balanceBefore;

        assertApproxEqAbs(strategy.collateral(), 123170_26476024, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 82113_50984016, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 1_50000000, USD_DELTA
        );
        assertApproxEqAbs(strategy.totalAssets(), 22.8235 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.totalSupply(), 970 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.balanceOf(alice), 0 ether, ETH_DELTA);
        assertApproxEqAbs(withdrawnAmount, 0.6315789474 ether, ETH_DELTA);
    }

    /// @notice rebalances the pool due to collateral price change
    /// @notice scenario 5 in the gsheet
    function test_scenario_5_rebalanceWhenCollateralPriceChange() public {
        _setupScenario(100 ether, 300, 300, 1000 ether);
        _changeLtv(CbETH, 9000, 9500, 10_500);

        assertEq(strategy.currentCollateralRatio(), 1_50000000);
        assertEq(strategy.rebalanceNeeded(), false);

        _changePrice(CbETH, 1400 * 1e8);

        assertEq(strategy.currentCollateralRatio(), 1_16739406);
        assertEq(strategy.rebalanceNeeded(), true);

        strategy.rebalance();

        assertEq(strategy.currentCollateralRatio(), 1_50000000);
        assertEq(strategy.rebalanceNeeded(), false);

        _changePrice(CbETH, 1500 * 1e8);

        assertEq(strategy.currentCollateralRatio(), 1_60714286);
        assertEq(strategy.rebalanceNeeded(), true);

        strategy.rebalance();

        assertEq(strategy.currentCollateralRatio(), 1_50000000);
        assertEq(strategy.rebalanceNeeded(), false);
    }

    /// @notice withdraws large part of the pool and then withdraws everything that is left
    function test_scenario_6_bigWithdrawals() public {
        _setupScenario(100 ether, 300, 300, 1000 ether);
        deal(address(strategy), alice, 700 ether, false);
        deal(address(strategy), bob, 300 ether, false);

        assertEq(strategy.collateral(), 179887_84372200);
        assertEq(strategy.debt(), 119925_22914800);
        assertEq(strategy.currentCollateralRatio(), 1_50000000);

        vm.startPrank(alice);
        strategy.redeem(700 ether, alice, alice);
        vm.stopPrank();

        assertApproxEqAbs(strategy.collateral(), 53966_35311660, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 35977_56874100, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 1_50000000, USD_DELTA
        );

        vm.startPrank(bob);
        strategy.redeem(300 ether, bob, bob);
        vm.stopPrank();

        assertEq(strategy.collateral(), 0);
        assertEq(strategy.debt(), 0);
        assertEq(strategy.currentCollateralRatio(), type(uint256).max);
    }
}
