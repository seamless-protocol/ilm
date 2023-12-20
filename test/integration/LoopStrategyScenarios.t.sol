// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

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
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "../unit/LoopStrategy.t.sol";

import "forge-std/console.sol";

/// @notice Scenario tests for the LoopStrategy
/// @notice gsheets models reference: https://docs.google.com/spreadsheets/d/1d9L_uX4qYCo6i7jxQXZjI55ogBsNhNI2q8jbdJ2P6g0
contract LoopStrategyScenariosTest is LoopStrategyTest {
    using USDWadRayMath for uint256;

    uint256 constant USD_DELTA = 0.0001 * 1e8;
    uint256 constant ETH_DELTA = 0.0001 ether;

    /// @dev setting up the starting parameters for scenarios
    /// @dev it assums CbETH as collateral asset and USDbC as borrowing asset
    /// @param startCollateral total collateral currently supplied to the lending pool from the strategy
    /// @param startLeverage current leverage ratio
    /// @param targetLeverage target leverage ratio for the pool
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

        // price at block number: 5_950_437
        _changePrice(CbETH, 179_887_843_722);
        _changePrice(USDbC, 100_000_000);
        swapOffset = 5e6;
        SwapperMock(address(swapper)).setOffsets(swapOffset, swapOffset);

        _changeLtv(CbETH, 8000, 8500, 10_500);

        uint256 startDebtUSD = (
            startCollateral * 179_887_843_722 * (startLeverage - 100)
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

        assertEq(strategy.collateral(), 179_887_843_722);
        assertEq(strategy.debt(), 119_925_229_100);
        assertEq(strategy.currentCollateralRatio(), 150_000_000);
        assertEq(strategy.totalAssets(), 333_333_330_000_000_000);
        assertEq(strategy.totalSupply(), 1000 ether);

        _depositFor(alice, 0.1 ether);

        // we are doing approximate equals because there is different losing of precision between gsheets model and solidity calculations
        assertApproxEqAbs(strategy.collateral(), 228_948_164_700, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 152_632_109_800, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 150_000_000, USD_DELTA
        );
        assertApproxEqAbs(strategy.totalAssets(), 0.4242 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.totalSupply(), 1272.7273 ether, ETH_DELTA);
        assertApproxEqAbs(strategy.balanceOf(alice), 272.7273 ether, ETH_DELTA);
    }

    /// @notice deposit when pool should rebalance before processing the new deposit
    /// @notice scneraio 2 in the gsheet
    function test_scenario_2_depositWhenPoolBelowMinForRebalance() public {
        _setupScenario(1 ether, 400, 350, 1000 ether);

        assertEq(strategy.collateral(), 179_887_843_722);
        assertEq(strategy.debt(), 134_915_882_700);
        assertEq(strategy.currentCollateralRatio(), 133_333_333);
        assertEq(strategy.totalAssets(), 250_000_000_000_000_000);
        assertEq(strategy.totalSupply(), 1000 ether);

        _depositFor(alice, 0.01 ether);

        assertApproxEqAbs(strategy.collateral(), 158_228_620_500, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 113_020_443_200, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 140_000_000, USD_DELTA
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

        assertEq(strategy.collateral(), 17_988_784_372_200);
        assertEq(strategy.debt(), 11_992_522_914_800);
        assertEq(strategy.currentCollateralRatio(), 150_000_000);
        assertEq(strategy.totalAssets(), 33_333_333_330_000_000_000);
        assertEq(strategy.totalSupply(), 1000 ether);
        assertEq(strategy.balanceOf(alice), 30 ether);

        uint256 balanceBefore = CbETH.balanceOf(alice);
        vm.startPrank(alice);
        strategy.redeem(30 ether, alice, alice);
        vm.stopPrank();
        uint256 withdrawnAmount = CbETH.balanceOf(alice) - balanceBefore;

        assertApproxEqAbs(strategy.collateral(), 17_449_120_841_034, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 11_632_747_227_356, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 150_000_000, USD_DELTA
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

        assertEq(strategy.collateral(), 17_988_784_372_200);
        assertEq(strategy.debt(), 13_491_588_279_100);
        assertEq(strategy.currentCollateralRatio(), 133_333_333);
        assertEq(strategy.totalAssets(), 25_000_000_000_000_000_000);
        assertEq(strategy.totalSupply(), 1000 ether);
        assertEq(strategy.balanceOf(alice), 30 ether);

        uint256 balanceBefore = CbETH.balanceOf(alice);
        vm.startPrank(alice);
        strategy.redeem(30 ether, alice, alice);
        vm.stopPrank();
        uint256 withdrawnAmount = CbETH.balanceOf(alice) - balanceBefore;

        assertApproxEqAbs(strategy.collateral(), 12_317_026_476_024, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 8_211_350_984_016, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 150_000_000, USD_DELTA
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

        assertEq(strategy.currentCollateralRatio(), 150_000_000);
        assertEq(strategy.rebalanceNeeded(), false);

        _changePrice(CbETH, 1400 * 1e8);

        assertEq(strategy.currentCollateralRatio(), 116_739_406);
        assertEq(strategy.rebalanceNeeded(), true);

        strategy.rebalance();

        assertEq(strategy.currentCollateralRatio(), 150_000_000);
        assertEq(strategy.rebalanceNeeded(), false);

        _changePrice(CbETH, 1500 * 1e8);

        assertEq(strategy.currentCollateralRatio(), 160_714_286);
        assertEq(strategy.rebalanceNeeded(), true);

        strategy.rebalance();

        assertEq(strategy.currentCollateralRatio(), 150_000_000);
        assertEq(strategy.rebalanceNeeded(), false);
    }

    /// @notice withdraws large part of the pool and then withdraws everything that is left
    function test_scenario_6_bigWithdrawals() public {
        _setupScenario(100 ether, 300, 300, 1000 ether);
        deal(address(strategy), alice, 700 ether, false);
        deal(address(strategy), bob, 300 ether, false);

        assertEq(strategy.collateral(), 17_988_784_372_200);
        assertEq(strategy.debt(), 11_992_522_914_800);
        assertEq(strategy.currentCollateralRatio(), 150_000_000);

        vm.startPrank(alice);
        strategy.redeem(700 ether, alice, alice);
        vm.stopPrank();

        assertApproxEqAbs(strategy.collateral(), 5_396_635_311_660, USD_DELTA);
        assertApproxEqAbs(strategy.debt(), 3_597_756_874_100, USD_DELTA);
        assertApproxEqAbs(
            strategy.currentCollateralRatio(), 150_000_000, USD_DELTA
        );

        vm.startPrank(bob);
        strategy.redeem(300 ether, bob, bob);
        vm.stopPrank();

        assertEq(strategy.collateral(), 0);
        assertEq(strategy.debt(), 0);
        assertEq(strategy.currentCollateralRatio(), type(uint256).max);
    }
}
