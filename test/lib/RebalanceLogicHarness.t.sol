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

       borrowAsset.approve(address(borrowPool), MINT_AMOUNT / 1000);
       borrowPool.supply(address(this), MINT_AMOUNT / 1000);
   }

   
   /// @dev ensure that collateral ratio is the target collateral ratio after rebalanceUp
   function test_rebalanceUp_bringsCollateralRatioToTarget() public {
       uint256 ratio = RebalanceLogicMock.rebalanceUp(borrowPool, collateralRatio, LoanLogicMock.loanState(borrowPool, address(this)), oracle, swapper);
       assert(ratio == collateralRatio.target);
   }

  
}