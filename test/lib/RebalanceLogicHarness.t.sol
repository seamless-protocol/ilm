// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { MockSetup } from "./MockSetup.t.sol";
import { LoanLogicMock } from "../mock/LoanLogicMock.sol";
import { RebalanceLogicMock } from "../mock/RebalanceLogicMock.sol";
import { CollateralRatio, LoanState } from "../../src/types/DataTypes.sol";

import 'forge-std/console.sol';

/// @title RebalanceLogicHarness
/// @dev RebalanceLogicHarness contract which exposes library functions
contract RebalanceLogicHarness is Test, MockSetup {
   function setUp() public virtual override {
       super.setUp();

       collateralAsset.mint(address(this), MINT_AMOUNT);

       borrowAsset.approve(address(borrowPool), type(uint256).max);
       collateralAsset.approve(address(borrowPool), type(uint256).max);
       borrowPool.supply(address(this), MINT_AMOUNT / 1000000);
   }

   /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
   function test_rebalanceUp_bringsCollateralRatioToTarget() public {
      
            //collateralRatio.target = targetRatio;
            uint256 ratio = RebalanceLogicMock.rebalanceUp(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);
            assert(ratio == collateralRatio.target);
   }

     /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceDown
   function test_rebalanceDown_bringsCollateralRatioToTarget() public {
       // set target collateral ratio to being lower than target
       collateralRatio.target = 1.4e8;

       uint256 ratio = RebalanceLogicMock.rebalanceUp(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);

        assert(ratio == collateralRatio.target);

       collateralRatio.target = 1.5e8;
       ratio = RebalanceLogicMock.rebalanceDown(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);

       assert(ratio == collateralRatio.target);
   }
  
}