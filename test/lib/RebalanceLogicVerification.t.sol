// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { LoopStrategyStorage as Storage } from
    "../../src/storage/LoopStrategyStorage.sol";
    
import "forge-std/console.sol";

contract RebalanceLogicVerification is RebalanceLogicContext {
    function setUp() public override {
        super.setUp();

        assertEq(WETH.balanceOf(address(this)), MINT_AMOUNT);
    }

    /// @dev verifies against EquityModel - scenario 1 excel case by mimicking all actions and
    /// respective rebalances
    function test_EquityModel_ScenarioOne() public {
        uint256 startingAmountAsset = 1 ether;
        uint256 startingAmountUSD = RebalanceLogic.convertAssetToUSD(
            startingAmountAsset, WETH_price, 18
        );

        uint256 depositAmountAsset = 0.1 ether;
        uint256 usdDeposit =
            RebalanceLogic.convertAssetToUSD(depositAmountAsset, WETH_price, 18);

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
            RebalanceLogic.collateralRatioUSD(
                state.collateralUSD, state.debtUSD
            ),
            type(uint256).max
        );

        uint256 margin = $.ratioMargin * targetCR / USDWadRayMath.USD;
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        RebalanceLogic.rebalanceUp($, state, currentCR, targetCR);

        state = LoanLogic.getLoanState($.lendingPool);

        console.log('cUSD: ', state.collateralUSD);
        console.log('dUSD: ', state.debtUSD);

        currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        assertApproxEqAbs(currentCR, targetCR, margin);

        LoanLogic.supply($.lendingPool, $.assets.collateral, depositAmountAsset);

        state = LoanLogic.getLoanState($.lendingPool);

        currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        uint256 expectedCR = uint256(1.65e8);

        assertApproxEqAbs(currentCR, expectedCR, expectedCR / 1_000_000);
    }
}
