// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { MockSetup } from "./MockSetup.t.sol";
import { LoanLogicMock } from "../mock/LoanLogicMock.sol";
import { RebalanceLogicMock } from "../mock/RebalanceLogicMock.sol";
import { CollateralRatio, LoanState } from "../../src/types/DataTypes.sol";

/// @title RebalanceLogicHarness
/// @dev RebalanceLogicHarness contract which exposes library functions
contract RebalanceLogicHarness is Test, MockSetup {
   /// @dev sets up testing context
   function setUp() public virtual override {
       super.setUp();

       collateralAsset.mint(address(this), MINT_AMOUNT);

       borrowAsset.approve(address(borrowPool), type(uint256).max);
       collateralAsset.approve(address(borrowPool), type(uint256).max);
       borrowPool.supply(address(this), MINT_AMOUNT / 1000000);
   }

   /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
   function testFuzz_rebalanceUp_bringsCollateralRatioToTarget(uint256 targetRatio) public {
      vm.assume(targetRatio > 1.25e8);
      vm.assume(targetRatio < 100e8);

      collateralRatio.target = targetRatio;
      uint256 ratio = RebalanceLogicMock.rebalanceUp(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);

      assert(ratio == collateralRatio.target);
   }

   /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
   function testFuzz_rebalanceDown_bringsCollateralRatioToTarget(uint256 targetRatio) public {
       collateralRatio.target = 1.25e8;

       uint256 ratio = RebalanceLogicMock.rebalanceUp(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);

       assert(ratio == collateralRatio.target);

       vm.assume(targetRatio > 1.25e8);
       vm.assume(targetRatio < 12e8);

       collateralRatio.target = targetRatio;
       ratio = RebalanceLogicMock.rebalanceDown(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);
    
       // set a small error range of 2/1e8 
       assert(collateralRatio.target - 2 <= ratio || ratio <= collateralRatio.target + 2);
   }
  
}