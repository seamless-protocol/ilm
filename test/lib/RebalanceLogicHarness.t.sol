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
      uint256 ratio = RebalanceLogic.rebalanceUp(lendingPool, assets,  LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

      assert(ratio == targetCR);
   }

   // /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
   // function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(uint256 targetRatio) public {
   //    vm.assume(targetRatio > 1.25e8);
   //    vm.assume(targetRatio < 100e8);

   //    targetCR = targetRatio;
   //    uint256 ratio = RebalanceLogic.rebalanceUp(lendingPool, assets,  LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

   //    assert(ratio == targetCR);
   // }

   // /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
   // function testFuzz_rebalanceDown_bringsCollateralRatioToTarget(uint256 targetRatio) public {
   //     targetCR = 1.25e8;

   //     uint256 ratio = RebalanceLogic.rebalanceUp(lendingPool, assets, LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

   //     assert(ratio == targetCR);

   //     vm.assume(targetRatio > 1.25e8);
   //     vm.assume(targetRatio < 12e8);

   //     targetCR = targetRatio;
   //     ratio = RebalanceLogic.rebalanceDown(lendingPool, assets,  LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);
    
   //     // set a small error range of 2/1e8 
   //     assert(targetCR - 2 <= ratio || ratio <= targetCR + 2);
   // }
  
}