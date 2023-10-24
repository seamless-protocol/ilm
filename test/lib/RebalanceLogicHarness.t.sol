// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { MockSetup } from "./MockSetup.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { CollateralRatio, LoanState } from "../../src/types/DataTypes.sol";

/// @title RebalanceLogicHarness
/// @dev RebalanceLogicHarness contract which exposes library functions
contract RebalanceLogicHarness is Test, MockSetup {
   /// @dev sets up testing context
   function setUp() public virtual override {
       super.setUp();

    //    collateralAsset.mint(address(this), MINT_AMOUNT);

    //    borrowAsset.approve(address(borrowPool), type(uint256).max);
    //    collateralAsset.approve(address(borrowPool), type(uint256).max);
    //    borrowPool.supply(address(this), MINT_AMOUNT / 1000000);
   }

   /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
   function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(uint256 targetRatio) public {
      vm.assume(targetRatio > 1.25e8);
      vm.assume(targetRatio < 100e8);

      targetCR = targetRatio;
      uint256 ratio = RebalanceLogic.rebalanceUp(lendingPool, assets,  LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

      assert(ratio == targetCR);
   }

   /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
   function testFuzz_rebalanceDown_bringsCollateralRatioToTarget(uint256 targetRatio) public {
       targetCR = 1.25e8;

       uint256 ratio = RebalanceLogic.rebalanceUp(lendingPool, assets, LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);

       assert(ratio == targetCR);

       vm.assume(targetRatio > 1.25e8);
       vm.assume(targetRatio < 12e8);

       targetCR = targetRatio;
       ratio = RebalanceLogic.rebalanceDown(lendingPool, assets,  LoanLogic.getLoanState(lendingPool), targetCR, oracle, swapper);
    
       // set a small error range of 2/1e8 
       assert(targetCR - 2 <= ratio || ratio <= targetCR + 2);
   }
  
}