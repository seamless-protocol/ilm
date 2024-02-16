// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { IntegrationBase } from "./IntegrationBase.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @notice Test confirming deployment is done correctly and we can deposit and redeem funds
contract IntegrationBaseTest is IntegrationBase {
    /// @dev test confirming deployment is done correctly and we can deposit and redeem funds
    function test_integrationBaseTest() public {
        address user = makeAddr("user");

        uint256 amount = 1 ether;

        vm.startPrank(user);

        deal(address(underlyingToken), user, amount);
        underlyingToken.approve(address(strategy), amount);

        uint256 shares = strategy.deposit(amount, user);

        strategy.redeem(shares / 2, user, user);

        vm.stopPrank();
    }
}
