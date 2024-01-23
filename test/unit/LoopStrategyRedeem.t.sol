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
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
import { ConversionMath } from "../../src/libraries/math/ConversionMath.sol";
import { RebalanceMath } from "../../src/libraries/math/RebalanceMath.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "./LoopStrategy.t.sol";

/// @notice Unit tests for the LoopStrategy redeem flow
contract LoopStrategyRedeemTest is LoopStrategyTest {
    using USDWadRayMath for uint256;

    uint256 internal constant MARGIN = 0.000001 ether;
    uint256 internal constant DROPPED_COLLATERAL_PRICE = 1700 * 1e8;

    CollateralRatio targets;

    /// @dev sets up testing context
    function setUp() public virtual override {
        super.setUp();

        targets = strategy.getCollateralRatioTargets();
    }

    /// @dev tests that the redeemer only has to incur the cost of rebalancing up to the minForWithdrawRebalance
    /// limit, when the collateral ratio of the strategy is thrown below minForWithdrawRebalance limit due to the
    /// redemption
    function test_redeem_redeemerIncursSomeEquityCost_when_redeemThrowsCollateralRatioBelow_minForWithdrawRebalanceLimit(
    ) public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        // ensure strategy is above minForWithdrawRebalance limit
        assert(
            strategy.totalSupply() == aliceShares
                && strategy.balanceOf(alice) == aliceShares
        );
        assert(
            targets.minForWithdrawRebalance <= strategy.currentCollateralRatio()
        );
        assertApproxEqRel(
            strategy.currentCollateralRatio(), targets.target, MARGIN
        );

        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 redeemAmount = aliceShares / 2;
        uint256 initialAliceShares = strategy.balanceOf(alice);

        // grab pre-redeem key parameters of strategy/user state
        uint256 initialCollateralUSD = strategy.collateral();
        uint256 initialDebtUSD = strategy.debt();
        uint256 initialEquityUSD = strategy.equityUSD();
        uint256 initialAliceAssets = CbETH.balanceOf(alice);

        // calculate amount of debt, collateral and equity corresponding to shares to be redeemed
        uint256 initialShareDebtUSD = initialDebtUSD.usdMul(
            USDWadRayMath.wadToUSD(redeemAmount.wadDiv(initialTotalSupply))
        );
        uint256 initialShareCollateralUSD = initialCollateralUSD.usdMul(
            USDWadRayMath.wadToUSD(redeemAmount.wadDiv(initialTotalSupply))
        );
        uint256 initialShareEquityUSD =
            initialShareCollateralUSD - initialShareDebtUSD;

        // redeem half of alice's shares
        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(redeemAmount, alice, alice);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(initialAliceShares - redeemAmount == strategy.balanceOf(alice));

        // check collateral ratio is approximately the minForWithdrawRebalance limit
        // as expected, since until that limit redeeming is free
        assertApproxEqRel(
            strategy.currentCollateralRatio(),
            targets.minForWithdrawRebalance,
            MARGIN
        );

        // since no rebalance was needed on behalf of the strategy prior to redemption actions,
        // the freeEquityUSD amount can be calculated directly
        uint256 freeEquityUSD = initialCollateralUSD
            - targets.minForWithdrawRebalance.usdMul(initialDebtUSD);

        // shareDebtUSD must be adjusted since part of the debt corresponding to shareEquityUSD
        // does not have to be repaid (freeEquityUSD)
        uint256 adjustedShareDebtUSD = initialShareDebtUSD
            - freeEquityUSD.usdMul(initialShareDebtUSD).usdDiv(
                initialShareEquityUSD + initialShareDebtUSD - freeEquityUSD
            );
        // shareCollateralUSD must be adjusted since ince part of the debt corresponding to shareEquityUSD
        // does not have to be repaid (freeEquityUSD)
        uint256 adjustedShareCollateralUSD = initialShareCollateralUSD
            - freeEquityUSD.usdMul(initialShareDebtUSD).usdDiv(
                initialShareEquityUSD + initialShareDebtUSD - freeEquityUSD
            );

        // expected cost incurred for rebalancing is the cost associated with DEX fees
        uint256 expectedRebalanceCostUSD = (
            adjustedShareDebtUSD.usdMul(USDWadRayMath.USD + swapOffset).usdDiv(
                USDWadRayMath.USD
            )
        ).usdMul(swapOffset);

        // assets received by redeemer should be equivalent in value to the initialShareEquityUSD
        // minus the expected rebalance cost, since the redeemer is burdened with said cost
        uint256 expectedReceivedAssets = ConversionMath.convertUSDToAsset(
            (initialShareEquityUSD - expectedRebalanceCostUSD),
            COLLATERAL_PRICE,
            18
        );

        // strategy collateral and debt decrease should be the same as the collateral
        // corresponding to the shares after the freeEquity was accounted for
        // within a 0.0001% error margin
        assertApproxEqRel(
            initialCollateralUSD - strategy.collateral(),
            adjustedShareCollateralUSD,
            MARGIN
        );
        assertApproxEqRel(
            initialDebtUSD - strategy.debt(), adjustedShareDebtUSD, MARGIN
        );
        // strategy equity should decrease as much as the value of the shares was
        assertApproxEqRel(
            initialEquityUSD - strategy.equityUSD(),
            initialShareEquityUSD,
            MARGIN
        );

        // ensure that the assets received by redeemer are as expected
        assertApproxEqRel(receivedAssets, expectedReceivedAssets, MARGIN);
        assertApproxEqRel(
            CbETH.balanceOf(alice) - initialAliceAssets,
            expectedReceivedAssets,
            MARGIN
        );
    }

    /// @dev ensures that redeeming all shares results in the redeemer paying the cost to repay
    /// all the debt, and receiving all remaining equity
    function test_redeem_allShares() public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        // ensure strategy is above minForWithdrawRebalance limit
        assert(
            strategy.totalSupply() == aliceShares
                && strategy.balanceOf(alice) == aliceShares
        );
        assert(
            targets.minForWithdrawRebalance <= strategy.currentCollateralRatio()
        );
        assertApproxEqRel(
            strategy.currentCollateralRatio(), targets.target, MARGIN
        );

        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 redeemAmount = aliceShares;
        uint256 initialAliceShares = strategy.balanceOf(alice);

        // grab pre-redeem key parameters of strategy/user state
        uint256 initialCollateralUSD = strategy.collateral();
        uint256 initialDebtUSD = strategy.debt();
        uint256 initialAliceAssets = CbETH.balanceOf(alice);

        // calculate amount of debt, collateral and equity corresponding to shares to be redeemed
        uint256 initialShareDebtUSD = initialDebtUSD.usdMul(
            USDWadRayMath.wadToUSD(redeemAmount.wadDiv(initialTotalSupply))
        );
        uint256 initialShareCollateralUSD = initialCollateralUSD.usdMul(
            USDWadRayMath.wadToUSD(redeemAmount.wadDiv(initialTotalSupply))
        );
        uint256 initialShareEquityUSD =
            initialShareCollateralUSD - initialShareDebtUSD;

        // redeem all of alice's shares
        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(redeemAmount, alice, alice);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(initialAliceShares - redeemAmount == strategy.balanceOf(alice));
        assert(strategy.totalSupply() == 0);

        // ensure that the remaining collateral in USD is less than a cent
        assert(strategy.collateral() < USDWadRayMath.USD / 100);
        // ensure the full debt of strategy is repaid
        assert(strategy.debt() == 0);
        // ensure that the remaining equity in USD is less than a cent
        assert(strategy.equityUSD() < USDWadRayMath.USD / 100);

        // expected cost incurred for rebalancing is the cost associated with DEX fees
        // which is the amount of cost incurred to pay back entire debt of strategy
        uint256 expectedRebalanceCostUSD = (
            initialShareDebtUSD.usdMul(USDWadRayMath.USD + swapOffset).usdDiv(
                USDWadRayMath.USD
            )
        ).usdMul(swapOffset);

        // assets received by redeemer should be equivalent in value to the initialShareEquityUSD
        // minus the expected rebalance cost, since the redeemer is burdened with said cost
        uint256 expectedReceivedAssets = ConversionMath.convertUSDToAsset(
            (initialShareEquityUSD - expectedRebalanceCostUSD),
            COLLATERAL_PRICE,
            18
        );

        // ensure that the assets received by redeemer are as expected
        assertApproxEqRel(receivedAssets, expectedReceivedAssets, MARGIN);
        assertApproxEqRel(
            CbETH.balanceOf(alice) - initialAliceAssets,
            expectedReceivedAssets,
            MARGIN
        );

        // ensure all debt is repaid
        assertEq(strategy.debt(), 0);
    }

    /// @dev tests that the redeemer incurs no equity cost when the redemption does not throw the collateral ratio
    /// below minForWithdrawRebalance
    function test_redeem_redeemerIncursNoEquityCost_when_redeemDoesNotThrowCollateralRatioBelow_minForWithdrawRebalanceLimit(
    ) public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;

        uint256 aliceShares = _depositFor(alice, depositAmount);
        _depositFor(bob, depositAmount * 100); // deposit for bob, no need to account for their shares
        // ensure Alices's redeem is small enough to not need a rebalance after a redemption
        uint256 redeemAmount = aliceShares / 100_000;
        uint256 initialCR = strategy.currentCollateralRatio();

        // assert collateral ratio larger than min for withdraw
        assertApproxEqAbs(initialCR, collateralRatioTargets.target, MARGIN);
        assert(initialCR > targets.minForWithdrawRebalance);

        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 oldAliceShareBalance = strategy.balanceOf(alice);

        // // grab pre-redeem key parameters of strategy/user state
        uint256 oldCollateralUSD = strategy.collateral();
        uint256 oldEquityUSD = strategy.equityUSD();
        uint256 oldCollateralAssetBalance = CbETH.balanceOf(alice);

        uint256 preRedeemEquityUSD = strategy.equity();

        vm.prank(alice);
        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

        uint256 postRedeemEquityUSD = strategy.equity();

        // in the case where no strategy-wide rebalance is needed,
        // the received collateral _must_ be less than the equity lost by the strategy
        assertLe(receivedCollateral, preRedeemEquityUSD - postRedeemEquityUSD);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(oldAliceShareBalance - redeemAmount == strategy.balanceOf(alice));

        // redeemAmount / initialTotalSupply of shares were redeemed, therefore approximately redeemAmount / initialTotalSupply * equityUSD of collateral must have been
        // withdrawn, with no debt repaid since no rebalance was needed
        // the margin has been increased because of rounding errors - since the redemption value is so small,
        // small rounding errors are magnified, relatively
        assertApproxEqRel(
            oldCollateralUSD - strategy.collateral(),
            oldEquityUSD * redeemAmount / initialTotalSupply,
            0.015 ether
        );
        assertApproxEqRel(
            oldEquityUSD - strategy.equityUSD(),
            oldEquityUSD * redeemAmount / initialTotalSupply,
            0.015 ether
        );

        // ensure that redeemAmount / initialTotalSupply of the total equity of the strategy was transferred to Alice in the form of collateral asset, with a 0.0001% margin
        uint256 expectedTransferedTokens = ConversionMath.convertUSDToAsset(
            oldEquityUSD - strategy.equityUSD(), COLLATERAL_PRICE, 18
        );
        assertApproxEqRel(receivedCollateral, expectedTransferedTokens, MARGIN);
        assertApproxEqRel(
            CbETH.balanceOf(alice) - oldCollateralAssetBalance,
            expectedTransferedTokens,
            MARGIN
        );

        // check collateral ratio is approximately as it was prior to redemption,
        // within an error margin of 0.0001%
        assertApproxEqRel(strategy.currentCollateralRatio(), initialCR, MARGIN);
    }

    /// @dev tests the case where a strategy wide rebalance has to occur due to a price change,
    /// prior to the redemption for the redeemer
    function test_redeem_performsStrategyWideRebalance_noRedeemerRebalanceNecessary(
    ) public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 20 ether;

        uint256 aliceShares = _depositFor(alice, depositAmount);
        _depositFor(bob, depositAmount * 100); // deposit for bob, no need to account for their shares

        // ensure Alices's redeem is small enough to not need a rebalance after a redemption
        uint256 redeemAmount = aliceShares / 100_000;
        uint256 initialCR = strategy.currentCollateralRatio();
        // assert collateral ratio is such that its between max for deposit and min for withdraw
        assertApproxEqAbs(initialCR, collateralRatioTargets.target, 20 * 1e6);

        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 oldAliceShareBalance = strategy.balanceOf(alice);

        // change price of CbETH so that a strategy wide rebalance is needed
        _changePrice(CbETH, DROPPED_COLLATERAL_PRICE);

        // calculate amount of collateral needed to bring the collateral ratio
        // to target, on the strategy wide rebalance
        uint256 neededCollateralUSD = RebalanceMath.requiredCollateralUSD(
            collateralRatioTargets.target,
            strategy.collateral(),
            strategy.debt(),
            swapOffset
        );

        // calculate new debt and collateral values after collateral has been exchanged
        // for rebalance
        uint256 expectedCollateralUSD =
            strategy.collateral() - neededCollateralUSD;
        uint256 expectedDebtUSD = strategy.debt()
            - RebalanceMath.offsetUSDAmountDown(neededCollateralUSD, swapOffset);
        uint256 expectedCR = RebalanceMath.collateralRatioUSD(
            expectedCollateralUSD, expectedDebtUSD
        );

        // ensure the resulting collateral ratio is the target after exchanging
        // the calculated collateral
        assertEq(collateralRatioTargets.target, expectedCR);

        // grab pre-redeem key parameters of strategy/user state
        // insofar as calculating user received collateral tokens goes
        uint256 oldCollateralUSD = expectedCollateralUSD;
        uint256 oldEquityUSD = expectedCollateralUSD - expectedDebtUSD;
        uint256 oldCollateralAssetBalance = CbETH.balanceOf(alice);

        vm.prank(alice);
        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

        // ensure that the received collateral is less than or equal to the equity lost by the strategy
        assertLe(
            receivedCollateral,
            ConversionMath.convertUSDToAsset(
                expectedCollateralUSD - expectedDebtUSD - strategy.equityUSD(),
                DROPPED_COLLATERAL_PRICE,
                18
            )
        );

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(oldAliceShareBalance - redeemAmount == strategy.balanceOf(alice));

        // redeemAmount / initialTotalSupply of shares were redeemed, therefore approximately redeemAmount / initialTotalSupply * equityUSD
        //of collateral must have been withdrawn, with no debt repaid since no rebalance on  behalf of the user was needed
        // the margin has been increased because of rounding errors - since the redemption value is so small,
        // small rounding errors are magnified, relatively
        // the oldCollateralUSD/oldEquityUSD values used, are those expected after the strategy wide rebalance
        assertApproxEqRel(
            oldCollateralUSD - strategy.collateral(),
            oldEquityUSD * redeemAmount / initialTotalSupply,
            0.015 ether
        );
        assertApproxEqRel(
            oldEquityUSD - strategy.equityUSD(),
            oldEquityUSD * redeemAmount / initialTotalSupply,
            0.015 ether
        );

        // ensure that redeemAmount / initialTotalSupply of the total equity of the strategy
        // was transferred to Alice in the form of collateral asset, with a 0.0001% margin
        uint256 expectedTransferedTokens = ConversionMath.convertUSDToAsset(
            oldEquityUSD - strategy.equityUSD(), DROPPED_COLLATERAL_PRICE, 18
        );
        assertApproxEqRel(receivedCollateral, expectedTransferedTokens, MARGIN, "asdasd");
        assertApproxEqRel(
            CbETH.balanceOf(alice) - oldCollateralAssetBalance,
            expectedTransferedTokens,
            MARGIN
        );

        // check collateral ratio is approximately as it was prior to user redemption,
        // after the strategy-wide rebalance within an error margin of 0.0001%
        assertApproxEqRel(strategy.currentCollateralRatio(), expectedCR, MARGIN);
    }

    /// @dev ensures that the predicted assets returned by the preview redeem call
    /// match the amount returned by the actual call when the redemption results in
    /// collateral ratio falling below minForWithdrawRebalance
    function test_previewRedeem_accurateEquityPrediction_whenRedemptionResultsInRatioLessThan_minForWithdrawRebalance(
    ) public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        // assert post-deposit state
        assert(
            strategy.totalSupply() == aliceShares
                && strategy.balanceOf(alice) == aliceShares
        );
        assertApproxEqRel(
            strategy.currentCollateralRatio(),
            collateralRatioTargets.target,
            MARGIN
        );

        uint256 redeemAmount = aliceShares / 2;
        uint256 predictedAliceAssets = strategy.previewRedeem(redeemAmount);
        vm.prank(alice);
        uint256 actualAliceAssets = strategy.redeem(redeemAmount, alice, alice);

        assertApproxEqRel(predictedAliceAssets, actualAliceAssets, MARGIN);

        // if the current collateral ratio is approxiamtely equal to minForWithdrawRebalance,
        // then the strategy's collateral ratio was thrown below minForWithdrawRebalance
        // and the redeemer rebalanced in such a way as to end up at minForWithdrawRebalance ratio
        assertApproxEqRel(
            strategy.currentCollateralRatio(),
            targets.minForWithdrawRebalance,
            MARGIN
        );
    }

    /// @dev ensures that the predicted assets returned by the preview redeem call
    /// match the amount returned by the actual call when the redemption results in
    /// collateral ratio not falling below minForWithdrawRebalance
    function test_previewRedeem_accurateEquityPrediction_whenRedemptionResultsInRatioLargerThan_minForWithdrawRebalance(
    ) public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;

        uint256 aliceShares = _depositFor(alice, depositAmount);
        _depositFor(bob, depositAmount * 100); // deposit for bob, no need to account for their shares
        // ensure Alices's redeem is small enough to not need a rebalance after a redemption
        uint256 redeemAmount = aliceShares / 100_000;
        uint256 initialCR = strategy.currentCollateralRatio();

        // assert collateral ratio larger than min for withdraw
        assertApproxEqAbs(initialCR, collateralRatioTargets.target, MARGIN);
        assert(initialCR > targets.minForWithdrawRebalance);

        uint256 predictedAliceAssets = strategy.previewRedeem(redeemAmount);
        vm.prank(alice);
        uint256 actualAliceAssets = strategy.redeem(redeemAmount, alice, alice);

        assertEq(predictedAliceAssets, actualAliceAssets);

        // if the current collateral ratio is larger than minForWithdrawRebalance,
        // then the strategy's collateral ratio was not thrown below minForWithdrawRebalance
        // and no rebalance was needed
        assert(
            strategy.currentCollateralRatio() > targets.minForWithdrawRebalance
        );
    }

    /// @dev ensures that redemptions work as intended even when the borrow capacity
    /// of the lending pool has been reached
    function test_redeem_afterBorrowCapOnLendingPoolIsExceeded() public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;

        uint256 aliceShares = _depositFor(alice, depositAmount);
        _depositFor(bob, depositAmount);

        assertEq(
            strategy.currentCollateralRatio(),
            strategy.getCollateralRatioTargets().maxForDepositRebalance
        );

        // change borrow cap so that it is now exceeded
        _changeBorrowCap(USDbC, 100_000);

        // deposit to increase strategy collateral ratio greatly
        _depositFor(bob, depositAmount);

        assert(
            strategy.currentCollateralRatio()
                > strategy.getCollateralRatioTargets().maxForRebalance
        );

        uint256 initialTotalSupply = strategy.totalSupply();

        // grab pre-redeem key parameters of strategy/user state
        uint256 initialCollateralUSD = strategy.collateral();
        uint256 initialDebtUSD = strategy.debt();

        // calculate amount of debt, collateral and equity corresponding to shares to be redeemed
        uint256 initialShareDebtUSD = initialDebtUSD.usdMul(
            USDWadRayMath.wadToUSD(aliceShares.wadDiv(initialTotalSupply))
        );
        uint256 initialShareCollateralUSD = initialCollateralUSD.usdMul(
            USDWadRayMath.wadToUSD(aliceShares.wadDiv(initialTotalSupply))
        );
        uint256 initialShareEquityUSD =
            initialShareCollateralUSD - initialShareDebtUSD;

        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(aliceShares, alice, alice);

        // since strategy has a much higher collateral ratio, it should follow that redemption
        // incurs no equity cost
        uint256 expectedAssets = ConversionMath.convertUSDToAsset(
            initialShareEquityUSD, COLLATERAL_PRICE, 18
        );

        assertEq(receivedAssets, expectedAssets);
    }

    /// @dev ensures that the predicted assets returned by the preview redeem call
    /// match the amount returned by the actual call when the redemption is for all
    /// the remaining shares
    function test_previewRedeem_accurateEquityPredicition_whenBurningAllShares()
        public
    {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        // ensure strategy is above minForWithdrawRebalance limit
        assert(
            strategy.totalSupply() == aliceShares
                && strategy.balanceOf(alice) == aliceShares
        );
        assert(
            targets.minForWithdrawRebalance <= strategy.currentCollateralRatio()
        );
        assertApproxEqRel(
            strategy.currentCollateralRatio(), targets.target, MARGIN
        );

        uint256 expectedReceivedAssets = strategy.previewRedeem(aliceShares);

        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(aliceShares, alice, alice);

        assertApproxEqRel(receivedAssets, expectedReceivedAssets, MARGIN);
    }

    /// @dev tests that if less than the minimum requested underlying assets are received,
    /// the redeem call reverts
    function test_redeem_revertsWhen_underlyingAssetReceivedIsLessThanMinimum()
        public
    {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        uint256 minUnderlyingAssets = type(uint256).max;

        uint256 redeemAmount = aliceShares / 2;

        // we don't have exact error revert check because we expect
        // UnderlyingReceivedBelowMinimum which has a parameter of given assets
        // which we can't get exactly in this test
        vm.expectRevert();

        vm.prank(alice);
        strategy.redeem(redeemAmount, alice, alice, minUnderlyingAssets);
    }

    /// @dev tests that if the receiver is not the owner, and the caller is not the owner,
    /// then the redeem transaction should revert
    function test_redeem_revertsWhen_receiverCallerIsNotOwnerAndCallerDoesNotHaveEnoughAllowance(
    ) public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        uint256 redeemAmount = aliceShares / 2;

        vm.expectRevert();

        vm.prank(bob);
        strategy.redeem(redeemAmount, bob, alice);
    }
}
