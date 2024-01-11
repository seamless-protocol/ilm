// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { ConversionMath } from "../../src/libraries/math/ConversionMath.sol";
import { RebalanceMath } from "../../src/libraries/math/RebalanceMath.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { LoopStrategyStorage as Storage } from
    "../../src/storage/LoopStrategyStorage.sol";

/// @title RebalanceLogicVerification contract
/// @dev Tests some of the scenarios in the EquityModel excel sheet
contract RebalanceLogicVerification is RebalanceLogicContext {
    function setUp() public override {
        super.setUp();

        assertEq(WETH.balanceOf(address(this)), MINT_AMOUNT);
    }

    /// @dev verifies against EquityModel - scenario 1 excel case by mimicking all actions and
    /// respective rebalances
    function test_EquityModel_ScenarioOne() public {
        // a bit more than a third to hit as close as possible to 1 ETH after rebalancing upwards for
        // 3x leverage
        uint256 startingAmountAsset = uint256(1 ether) * 11 / 30;
        uint256 startingAmountUSD = ConversionMath.convertAssetToUSD(
            startingAmountAsset, WETH_price, 18
        );

        uint256 depositAmountAsset = 0.1 ether;

        LoanLogic.supply(
            $.lendingPool, $.assets.collateral, startingAmountAsset
        );

        uint256 targetCR = $.collateralRatioTargets.target;

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        assertApproxEqAbs(
            state.collateralUSD, startingAmountUSD, startingAmountUSD / 100_000
        );
        assertEq(state.debtUSD, 0);
        assertEq(
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD),
            type(uint256).max
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        uint256 currentCR = RebalanceLogic.rebalanceTo($, state, targetCR);

        state = LoanLogic.getLoanState($.lendingPool);

        // expect to leverage up to approximately 1 WETH in USD value and 2/3 of that in debt
        assertApproxEqAbs(state.collateralUSD, WETH_price, WETH_price / 100_000);
        assertApproxEqAbs(
            state.debtUSD, WETH_price * 2 / 3, WETH_price * 2 / (3 * 100_000)
        );
        assertApproxEqAbs(currentCR, targetCR, margin);

        state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, depositAmountAsset
        );

        // expect to have approximately 1.1x WETH_price in collateralUSD value
        assertApproxEqAbs(
            state.collateralUSD,
            WETH_price * 11 / 10,
            WETH_price * 11 / (10 * 100_000)
        );

        state = LoanLogic.getLoanState($.lendingPool);

        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        // expectedCR taken from scenario case
        uint256 expectedCR = uint256(1.65e8);

        assertApproxEqAbs(currentCR, expectedCR, expectedCR / 1_000_000);

        currentCR = RebalanceLogic.rebalanceTo($, state, targetCR);

        state = LoanLogic.getLoanState($.lendingPool);

        // expect to leverage up to approximately 14 / 11 WETH USD valuem, and 2/3 of that in debt
        assertApproxEqAbs(
            state.collateralUSD,
            WETH_price * 14 / 11,
            WETH_price * 14 / (11 * 100_000)
        );
        assertApproxEqAbs(
            state.debtUSD,
            WETH_price * 28 / 33,
            WETH_price * 28 / (33 * 100_000)
        );
        assertApproxEqAbs(currentCR, targetCR, margin);
    }

    /// @dev verifies against EquityModel - scenario 2 excel case by mimicking all actions and
    // respective rebalances
    function test_EquityModel_ScenarioTwo() public {
        // a bit more than a quarter to hit as close as possible to 1 ETH after rebalancing upwards for
        // 3x leverage
        // value is found heuristically
        uint256 startingAmountAsset = uint256(1 ether) * 288_143 / 1_000_000;
        uint256 startingAmountUSD = ConversionMath.convertAssetToUSD(
            startingAmountAsset, WETH_price, 18
        );

        uint256 depositAmountAsset = 0.01 ether;

        LoanState memory state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, startingAmountAsset
        );

        uint256 targetCR = $.collateralRatioTargets.target;

        assertApproxEqAbs(
            state.collateralUSD, startingAmountUSD, startingAmountUSD / 100_000
        );
        assertEq(state.debtUSD, 0);
        assertEq(
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD),
            type(uint256).max
        );

        // set targetCR to be max of 1.33333333e8 and maxIterations to be 25 (to reach the targetCR)
        targetCR = 1.33333333e8;
        $.maxIterations = 25;
        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        uint256 currentCR = RebalanceLogic.rebalanceTo($, state, targetCR);

        state = LoanLogic.getLoanState($.lendingPool);

        // allow more error on USD values
        assertApproxEqAbs(state.collateralUSD, WETH_price, WETH_price / 1000);
        // allow more error on USD values
        assertApproxEqAbs(
            state.debtUSD, WETH_price * 3 / 4, WETH_price * 3 / (4 * 1000)
        );
        assertApproxEqAbs(currentCR, targetCR, margin);

        targetCR = 1.4e8;
        currentCR = RebalanceLogic.rebalanceTo($, state, targetCR);
        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(currentCR, targetCR, margin);

        state = LoanLogic.supply(
            $.lendingPool, $.assets.collateral, depositAmountAsset
        );
        currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 expectedCR = 1.4165e8;

        // allow more error on expectedCR due to conversions
        assertApproxEqAbs(currentCR, expectedCR, expectedCR / 10_000);

        targetCR = 1.4e8;
        currentCR = RebalanceLogic.rebalanceTo($, state, targetCR);
        margin = $.ratioMargin * targetCR / USDWadRayMath.USD;

        assertApproxEqAbs(currentCR, targetCR, margin);

        state = LoanLogic.getLoanState($.lendingPool);
    }
}
