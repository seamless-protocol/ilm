// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { RebalanceLogicContext } from "./RebalanceLogicContext.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";

/// @title RebalanceLogicHarness
/// @dev RebalanceLogicHarness contract which exposes RebalanceLogic library functions
contract RebalanceLogicHarness is RebalanceLogicContext {
    //address public SUPPLIER = address(123123123);
    /// @dev sets up testing context
    function setUp() public virtual override {
        super.setUp();

        LoanLogic.supply(lendingPool, assets.collateral, (MINT_AMOUNT / 10));
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    function test_rebalanceUp_bringsCollateralRatioToTarget() public {
        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool,
            assets,
            state,
            currentCR,
            targetCR,
            oracle,
            swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    function test_rebalanceDown_bringsCollateralRatioToTarget() public {
        // with 0.75 LTV, we have a min CR of 1.33e8
        // given by CR_min = 1 / LTV
        targetCR = 1.35e8;

        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool,
            assets,
            state,
            currentCR,
            targetCR,
            oracle,
            swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);

        targetCR = 3.5e8;

        state = LoanLogic.getLoanState(lendingPool);
        currentCR = RebalanceLogic.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        ratio = RebalanceLogic.rebalanceDown(
            lendingPool,
            assets,
            state,
            currentCR,
            targetCR,
            oracle,
            swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
    }

    /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
    function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(
        uint256 targetRatio
    ) public {
        // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
        vm.assume(targetRatio > 1.34e8);
        vm.assume(targetRatio < 50e8);

        targetCR = targetRatio;
        LoanState memory state = LoanLogic.getLoanState(lendingPool);
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(state.collateralUSD, state.debtUSD);
        
        uint256 ratio = RebalanceLogic.rebalanceUp(
            lendingPool,
            assets,
            state,
            currentCR,
            targetCR,
            oracle,
            swapper
        );

        assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
    }

    // /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
    // function testFuzz_rebalanceDown_bringsCollateralRatioToTarget(uint256 targetRatio) public {
    //      // slightly above min CR of 1.33e8 to allow for lack of precision owed to conversions
    //     targetCR = 1.34e8;

    //     uint256 ratio = RebalanceLogic.rebalanceUp(lendingPool, assets, LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

    //     assertApproxEqAbs(ratio, targetCR, targetCR / 100000);

    //     vm.assume(targetRatio > 1.35e8);
    //     vm.assume(targetRatio < 5e8);

    //     targetCR = targetRatio;
    //     ratio = RebalanceLogic.rebalanceDown(lendingPool, assets,  LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

    //      assertApproxEqAbs(ratio, targetCR, targetCR / 100000);
    // }
}
