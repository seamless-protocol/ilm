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

        (uint256 initialShareDebtUSD, uint256 initialShareEquityUSD) = LoanLogic
            .shareDebtAndEquity(
            LoanState({
                collateralUSD: initialCollateralUSD,
                debtUSD: initialDebtUSD,
                maxWithdrawAmount: 0
            }),
            redeemAmount,
            initialTotalSupply
        );

        uint256 initialShareCollateralUSD =
            initialShareDebtUSD + initialShareEquityUSD;

        uint256 initialEquityPerShare =
            initialEquityUSD.usdDiv(USDWadRayMath.wadToUSD(initialTotalSupply));

        // redeem half of alice's shares
        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(redeemAmount, alice, alice);

        uint256 finalEquityPerShare = (strategy.equityUSD()).usdDiv(
            USDWadRayMath.wadToUSD(strategy.totalSupply())
        );

        // invariant which must be preserved: equity per share does _not_ decrease
        assertGe(finalEquityPerShare, initialEquityPerShare);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(initialAliceShares - redeemAmount == strategy.balanceOf(alice));

        // check collateral ratio is the minForWithdrawRebalance limit
        // as expected, since until that limit redeeming is free
        assertEq(
            strategy.currentCollateralRatio(), targets.minForWithdrawRebalance
        );

        // debt needed to be repaid is adjusted since current CR is above minForWithdrawRebalance
        uint256 adjustedShareDebtUSD = (
            targets.minForWithdrawRebalance.usdMul(initialDebtUSD)
                - (initialCollateralUSD - initialShareEquityUSD)
        ).usdDiv(targets.minForWithdrawRebalance - USDWadRayMath.USD);

        uint256 expectedRebalanceCostUSD = adjustedShareDebtUSD.usdDiv(
            USDWadRayMath.USD - swapOffset
        ).usdMul(swapOffset);

        // shareCollateralUSD must be adjusted since part of the debt corresponding to shareEquityUSD
        // does not have to be repaid
        uint256 adjustedShareCollateralUSD = initialShareCollateralUSD
            - (initialShareDebtUSD - adjustedShareDebtUSD);

        // assets received by redeemer should be equivalent in value to the initialShareEquityUSD
        // minus the expected rebalance cost, since the redeemer is burdened with said cost
        uint256 expectedReceivedAssets = ConversionMath.convertUSDToAsset(
            (initialShareEquityUSD - expectedRebalanceCostUSD),
            COLLATERAL_PRICE,
            18,
            Math.Rounding.Floor
        );

        // strategy collateral decrease should be equivalent to share collateral after
        // accounting for the debt which does not have to be repaid
        assertApproxEqRel(
            initialCollateralUSD - strategy.collateral(),
            adjustedShareCollateralUSD,
            MARGIN
        );
        // strategy debt difference should be equivalent to debt repaid
        assertApproxEqRel(
            initialDebtUSD - strategy.debt(), adjustedShareDebtUSD, MARGIN
        );

        // strategy equity should decrease at most as much as share equity
        assertLe(initialEquityUSD - strategy.equityUSD(), initialShareEquityUSD);

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
        assertEq(strategy.totalSupply(), initialTotalSupply - redeemAmount);
        assertEq(initialAliceShares - redeemAmount, strategy.balanceOf(alice));
        assertEq(strategy.totalSupply(), 0);

        // ensure there is no remainin collateral
        assertEq(strategy.collateral(), 0);
        // ensure the full debt of strategy is repaid
        assertEq(strategy.debt(), 0);
        // ensure that the remaining equity in USD is calculated correctly to 0
        assertEq(strategy.equityUSD(), 0);

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
            18,
            Math.Rounding.Floor
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

        uint256 preRedeemEquity = strategy.equity();

        (uint256 shareDebtUSD, uint256 shareEquityUSD) = LoanLogic
            .shareDebtAndEquity(
            LoanState({
                collateralUSD: oldCollateralUSD,
                debtUSD: strategy.debt(),
                maxWithdrawAmount: 0
            }),
            redeemAmount,
            initialTotalSupply
        );

        uint256 initialEquityPerShare = USDWadRayMath.wadToUSD(
            USDWadRayMath.usdToWad(strategy.equityUSD()).wadDiv(
                strategy.totalSupply()
            )
        );

        vm.prank(alice);
        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

        uint256 finalEquityPerShare = USDWadRayMath.wadToUSD(
            USDWadRayMath.usdToWad(strategy.equityUSD()).wadDiv(
                strategy.totalSupply()
            )
        );

        // invariant which must be preserved: equity per share does _not_ decrease
        assertGe(finalEquityPerShare, initialEquityPerShare);

        uint256 postRedeemEquity = strategy.equity();

        // in the case where no strategy-wide rebalance is needed,
        // the received collateral _must_ be less than the equity decrease of the strategy
        assertLe(receivedCollateral, preRedeemEquity - postRedeemEquity);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(oldAliceShareBalance - redeemAmount == strategy.balanceOf(alice));

        // strategy collateral and equity must decrease exactly by share equity,
        // as no rebalancing was needed after redeeming
        assertEq(oldCollateralUSD - strategy.collateral(), shareEquityUSD);
        assertEq(oldEquityUSD - strategy.equityUSD(), shareEquityUSD);

        // ensure that an amount of underlying tokens equal in value to shareEquityUSD
        // was transferred
        uint256 expectedTransferedTokens = ConversionMath.convertUSDToAsset(
            shareEquityUSD, COLLATERAL_PRICE, 18, Math.Rounding.Floor
        );
        assertEq(receivedCollateral, expectedTransferedTokens);
        assertEq(
            CbETH.balanceOf(alice) - oldCollateralAssetBalance,
            expectedTransferedTokens
        );

        // check collateral ratio is less (increased exposure) than it was
        // prior to redemption
        assertLe(strategy.currentCollateralRatio(), initialCR);
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
        assertEq(
            strategy.currentCollateralRatio(), targets.maxForDepositRebalance
        );

        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 oldAliceShareBalance = strategy.balanceOf(alice);

        // change price of CbETH so that a strategy wide rebalance is needed
        _changePrice(CbETH, DROPPED_COLLATERAL_PRICE);

        // calculate amount of collateral needed to bring the collateral ratio
        // to target, on the strategy wide rebalance
        uint256 neededCollateralUSD = RebalanceMath.requiredCollateralUSD(
            targets.target, strategy.collateral(), strategy.debt(), swapOffset
        );

        // calculate new debt and collateral values after collateral has been exchanged
        // for rebalance
        uint256 expectedCollateralUSD =
            strategy.collateral() - neededCollateralUSD;
        uint256 expectedDebtUSD = strategy.debt() - neededCollateralUSD
            + neededCollateralUSD.usdMul(swapOffset); // TODO: this value is off by 20 wei, recheck with rounding pr
        uint256 expectedCR = RebalanceMath.collateralRatioUSD(
            expectedCollateralUSD, expectedDebtUSD
        );
        assertEq(targets.target, expectedCR);

        uint256 oldCollateralAssetBalance = CbETH.balanceOf(alice);

        (uint256 initialShareDebtUSD, uint256 initialShareEquityUSD) = LoanLogic
            .shareDebtAndEquity(
            LoanState({
                collateralUSD: expectedCollateralUSD,
                debtUSD: expectedDebtUSD,
                maxWithdrawAmount: 0
            }),
            redeemAmount,
            initialTotalSupply
        );

        uint256 initialEquityPerShare = USDWadRayMath.wadToUSD(
            USDWadRayMath.usdToWad(expectedCollateralUSD - expectedDebtUSD)
                .wadDiv(strategy.totalSupply())
        );

        vm.prank(alice);
        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

        uint256 finalEquityPerShare = USDWadRayMath.wadToUSD(
            USDWadRayMath.usdToWad(strategy.equityUSD()).wadDiv(
                strategy.totalSupply()
            )
        );

        // invariant which must be preserved: equity per share does _not_ decrease
        assertGe(finalEquityPerShare, initialEquityPerShare);

        // ensure that the received collateral is less than or equal to the equity lost by the strategy
        assertLe(
            receivedCollateral,
            ConversionMath.convertUSDToAsset(
                initialShareEquityUSD,
                DROPPED_COLLATERAL_PRICE,
                18,
                Math.Rounding.Floor
            )
        );

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(oldAliceShareBalance - redeemAmount == strategy.balanceOf(alice));

        // collateral withdrawn from redeem must be equal to initialShareEquityUSD
        // as no rebalance cost burdened redeemer
        assertEq(
            expectedCollateralUSD - strategy.collateral(), initialShareEquityUSD
        );
        assertApproxEqRel(
            expectedCollateralUSD - expectedDebtUSD - strategy.equityUSD(),
            initialShareEquityUSD,
            0.000001 ether //accept some error due to precision loss
        );

        // ensure that redeemAmount / initialTotalSupply of the total equity of the strategy
        // was transferred to Alice in the form of collateral asset, with a 0.0001% margin
        uint256 expectedTransferedTokens = ConversionMath.convertUSDToAsset(
            initialShareEquityUSD,
            DROPPED_COLLATERAL_PRICE,
            18,
            Math.Rounding.Floor
        );

        assertEq(receivedCollateral, expectedTransferedTokens);
        assertEq(
            CbETH.balanceOf(alice) - oldCollateralAssetBalance,
            expectedTransferedTokens
        );

        // check collateral ratio is approximately as it was prior to user redemption,
        // after the strategy-wide rebalance within an error margin of 0.0001%
        assertApproxEqRel(strategy.currentCollateralRatio(), expectedCR, MARGIN);
    }

    /// @dev ensures that if a redemption leads to more equity being given to the strategy (equity extracted
    /// from the DEX), redeemer receives full equity value of shares, strategy equity increases, and share
    /// debt is paid in full
    function test_redeem_redeemerReceivesAllShareEquityValue_when_strategyGainsEquityFromSwap(
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

        (uint256 initialShareDebtUSD, uint256 initialShareEquityUSD) = LoanLogic
            .shareDebtAndEquity(
            LoanState({
                collateralUSD: initialCollateralUSD,
                debtUSD: initialDebtUSD,
                maxWithdrawAmount: 0
            }),
            redeemAmount,
            initialTotalSupply
        );

        uint256 realOffset = 1e8 + 15e6;
        // set offsets so that swap returns net positive value
        SwapperMock(address(swapper)).setRealOffsets(realOffset, realOffset);

        // redeem half of alice's shares
        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(redeemAmount, alice, alice);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(initialAliceShares - redeemAmount == strategy.balanceOf(alice));

        // assets received by redeemer should be equivalent in value to the initialShareEquityUSD
        // since excess equity was received by the strategy
        uint256 expectedReceivedAssets = ConversionMath.convertUSDToAsset(
            (initialShareEquityUSD), COLLATERAL_PRICE, 18, Math.Rounding.Floor
        );

        assertEq(expectedReceivedAssets, receivedAssets);

        // strategy equity should increase since swap gave net positive equity
        assertLe(initialEquityUSD - initialShareEquityUSD, strategy.equityUSD());

        // assert that at least the initialShareDebtUSD value has been repaid
        assertLt(initialShareDebtUSD, initialDebtUSD - strategy.debt());
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

        (uint256 initialShareDebtUSD, uint256 initialShareEquityUSD) = LoanLogic
            .shareDebtAndEquity(
            LoanState({
                collateralUSD: initialCollateralUSD,
                debtUSD: initialDebtUSD,
                maxWithdrawAmount: 0
            }),
            aliceShares,
            initialTotalSupply
        );

        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(aliceShares, alice, alice);

        // since strategy has a much higher collateral ratio, it should follow that redemption
        // incurs no equity cost
        uint256 expectedAssets = ConversionMath.convertUSDToAsset(
            initialShareEquityUSD, COLLATERAL_PRICE, 18, Math.Rounding.Floor
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

    /// @dev ensures that if slippage is too high, then redeem call will revert
    function test_redeem_revertsWhen_slippageIsTooHigh() public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        uint256 redeemAmount = aliceShares / 2;

        _setupSwapperWithMockAdapter();
        wethCbETHAdapter.setSlippagePCT(25);

        vm.expectRevert(ISwapper.MaxSlippageExceeded.selector);

        vm.prank(alice);
        strategy.redeem(redeemAmount, alice, alice);
    }

    /// @dev tests that user receives the correct amount of assets on redeem when debtUSD = 0
    /// @dev this can happen if user repays debt on behalf of the strategy, and borrow cap is reached
    function test_redeem_repayTotalDebtAttackWhileBorrowCapReached() public {
        // set dex fees to 0 for easier calculations
        SwapperMock(address(swapper)).setRealOffsets(0, 0);
        SwapperMock(address(swapper)).setOffsets(0, 0);

        // alice and bob both deposit the same amount to the strategy
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);
        uint256 bobShares = _depositFor(bob, depositAmount);

        (,, address debtUSDbCaddress) =
            poolDataProvider.getReserveTokensAddresses(address(USDbC));
        IERC20 dUSDbC = IERC20(debtUSDbCaddress);

        uint256 totalDebt = dUSDbC.balanceOf(address(strategy));
        deal(address(USDbC), bob, totalDebt);

        IPool pool = strategy.getLendingPool().pool;

        // assume that borrow cap is reached so we can't rebalance anymore before redeem
        _changeBorrowCap(USDbC, 0);

        // bob repays the whole debt on behalf of the strategy, then redeems all his shares
        vm.startPrank(bob);
        USDbC.approve(address(pool), totalDebt);
        pool.repay(address(USDbC), totalDebt, 2, address(strategy));
        assertEq(strategy.debt(), 0);
        uint256 equityBeforeRedeem = strategy.equity();
        uint256 totalAssetsReceived = strategy.redeem(bobShares, bob, bob);
        vm.stopPrank();

        // should get half of the equity because alice and bob have equal amount of shares
        assertEq(totalAssetsReceived, equityBeforeRedeem / 2);
    }

    /// @dev tests that user receives the correct amount of assets when he has
    /// almost all strategy shares and debtUSD = 0
    function test_redeem_userHasAlmostAllStrategyShares() public {
        uint256 targetCollateralUSD = 100000095;
        uint256 targetDebtUSD = 95;

        uint256 aliceShares = 9999;

        // bob has 1 share, and alice has all the rest
        deal(address(strategy), alice, aliceShares, true);
        deal(address(strategy), bob, 1, true);

        uint256 collateralAssets = (targetCollateralUSD * 1e18)
            / priceOracle.getAssetPrice(address(CbETH));

        IPool pool = strategy.getLendingPool().pool;

        deal(address(CbETH), address(strategy), collateralAssets);

        // setup the strategy with target collateral and debt
        vm.startPrank(address(strategy));
        CbETH.approve(address(pool), collateralAssets);
        pool.supply(address(CbETH), collateralAssets, address(strategy), 0);
        pool.borrow(address(USDbC), targetDebtUSD, 2, 0, address(strategy));
        vm.stopPrank();

        uint256 equityBeforeRedeem = strategy.equity();

        // assume that borrow cap is reached so we can't rebalance anymore before redeem
        _changeBorrowCap(USDbC, 0);

        // set dex fees to 0 for easier calculations
        SwapperMock(address(swapper)).setRealOffsets(0, 0);
        SwapperMock(address(swapper)).setOffsets(0, 0);

        // alice redeems all her shares
        vm.prank(alice);
        uint256 receivedAssets = strategy.redeem(aliceShares, alice, alice);

        // alice shouldn't get the whole equity
        assertLt(receivedAssets, equityBeforeRedeem);
        assertGt(strategy.collateral(), 0);
    }
}
