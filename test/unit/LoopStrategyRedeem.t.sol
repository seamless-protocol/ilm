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
import { LoopStrategyTest } from "./LoopStrategy.t.sol";

/// @notice Unit tests for the LoopStrategy redeem flow
contract LoopStrategyRedeemTest is LoopStrategyTest {
    using USDWadRayMath for uint256;

    uint256 internal constant MARGIN = 0.000001 ether;
    uint256 internal constant DROPPED_COLLATERAL_PRICE = 1700 * 1e8;

    /// @dev tests the case where the redeemer has to pay with equity for a rebalance
    /// caused from throwing the strategy out of acceptable ranges from their
    /// redemption
    function test_redeem_redeemerHasToPerformRebalance() public {
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
        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 oldBalance = strategy.balanceOf(alice);

        // grab pre-redeem key parameters of strategy/user state
        uint256 oldCollateralUSD = strategy.collateral();
        uint256 oldDebtUSD = strategy.debt();
        uint256 oldEquityUSD = strategy.equityUSD();
        uint256 oldCollateralAssetBalance = CbETH.balanceOf(alice);

        // redeem half of alice's shares
        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

        // assert that the expected amount of shares has been burnt
        assert(strategy.totalSupply() == initialTotalSupply - redeemAmount);
        assert(oldBalance - redeemAmount == strategy.balanceOf(alice));

        // 50% of shares were redeemed, therefore approximately 50% of collateral must have been
        // withdrawn, and 50% of the debt repaid, within a 0.0001% margin
        assertApproxEqRel(
            oldCollateralUSD - strategy.collateral(),
            oldCollateralUSD / 2,
            MARGIN
        );
        assertApproxEqRel(oldDebtUSD - strategy.debt(), oldDebtUSD / 2, MARGIN);
        assertApproxEqRel(
            oldEquityUSD - strategy.equityUSD(), oldEquityUSD / 2, MARGIN
        );

        // ensure that 50% of the total equity of the strategy was transferred to Alice, minus the rebalancing cost,
        // in the form of collateral asset, with a 0.0001% margin
        uint256 expectedRebalanceCostUSD = (
            (oldDebtUSD / 2) * (USDWadRayMath.USD + swapOffset)
                / (USDWadRayMath.USD)
        ).usdMul(swapOffset);

        uint256 expectedTransferedTokens = RebalanceLogic.convertUSDToAsset(
            (oldEquityUSD - strategy.equityUSD() - expectedRebalanceCostUSD),
            COLLATERAL_PRICE,
            18
        );

        assertApproxEqRel(receivedCollateral, expectedTransferedTokens, MARGIN);

        assertApproxEqRel(
            CbETH.balanceOf(alice) - oldCollateralAssetBalance,
            expectedTransferedTokens,
            MARGIN
        );

        // check collateral ratio is approximately the target, as expected
        assertApproxEqRel(
            strategy.currentCollateralRatio(),
            collateralRatioTargets.target,
            MARGIN
        );
    }

    /// @dev tests the case where no rebalance paid by the redeemer
    /// has to occur
    function test_redeem_noRedeemerRebalanceNecessary() public {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;

        uint256 aliceShares = _depositFor(alice, depositAmount);
        _depositFor(bob, depositAmount * 100); // deposit for bob, no need to account for their shares
        // ensure Alices's redeem is small enough to not need a rebalance after a redemption
        uint256 redeemAmount = aliceShares / 100_000;
        uint256 initialCR = strategy.currentCollateralRatio();

        // assert collateral ratio is such that its between max for deposit and min for withdraw
        assertApproxEqAbs(initialCR, collateralRatioTargets.target, 3 * 1e6);

        uint256 initialTotalSupply = strategy.totalSupply();
        uint256 oldAliceShareBalance = strategy.balanceOf(alice);

        // // grab pre-redeem key parameters of strategy/user state
        uint256 oldCollateralUSD = strategy.collateral();
        uint256 oldEquityUSD = strategy.equityUSD();
        uint256 oldCollateralAssetBalance = CbETH.balanceOf(alice);

        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

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
        uint256 expectedTransferedTokens = RebalanceLogic.convertUSDToAsset(
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
        uint256 depositAmount = 1 ether;

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
        uint256 neededCollateralUSD = RebalanceLogic.requiredCollateralUSD(
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
            - RebalanceLogic.offsetUSDAmountDown(neededCollateralUSD, swapOffset);
        uint256 expectedCR = RebalanceLogic.collateralRatioUSD(
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

        uint256 receivedCollateral = strategy.redeem(redeemAmount, alice, alice);

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
        uint256 expectedTransferedTokens = RebalanceLogic.convertUSDToAsset(
            oldEquityUSD - strategy.equityUSD(), DROPPED_COLLATERAL_PRICE, 18
        );
        assertApproxEqRel(receivedCollateral, expectedTransferedTokens, MARGIN);
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
    /// match the amount returned by the actual call
    function test_previewRedeem_accurateEquityPrediction() public {
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
        uint256 actualAliceAssets = strategy.redeem(redeemAmount, alice, alice);

        assertEq(predictedAliceAssets, actualAliceAssets);
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
        uint256 predictedAliceAssets = strategy.previewRedeem(redeemAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILoopStrategy.UnderlyingReceivedBelowMinimum.selector,
                predictedAliceAssets,
                minUnderlyingAssets
            )
        );

        strategy.redeem(redeemAmount, alice, alice, minUnderlyingAssets);
    }

    /// @dev tests that if the receiver is not the owner, and the caller is not the owner,
    /// then the redeem transaction should revert
    function test_redeem_revertsWhen_receiverIsNotOwnerAndCallerIsNotOwner()
        public
    {
        assertEq(strategy.totalSupply(), 0);
        uint256 depositAmount = 1 ether;
        uint256 aliceShares = _depositFor(alice, depositAmount);

        uint256 redeemAmount = aliceShares / 2;

        vm.expectRevert(ILoopStrategy.RedeemerNotOwner.selector);

        vm.prank(bob);
        strategy.redeem(redeemAmount, bob, alice);
    }
}
