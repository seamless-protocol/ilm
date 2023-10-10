// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { WrappedCbETH, IWrappedERC20PermissionedDeposit } from "../../src/tokens/WrappedCbETH.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract WrappedCbETHTest is Test {
    WrappedCbETH public wrappedCbETH;
    MockERC20 public mockERC20;

    address public alice = makeAddr("alice");

    function setUp() public {
        mockERC20 = new MockERC20("Mock", "M");
        wrappedCbETH = new WrappedCbETH("WrappedMock", "WM", IERC20(mockERC20), address(this));

        deal(address(mockERC20), address(alice), 100 ether);
    }

    function testSetup() public {
      assertEq(wrappedCbETH.owner(), address(this));
      assertEq(address(wrappedCbETH.underlying()), address(mockERC20));
    }

    function testNotDepositor() public {
      vm.startPrank(alice);
      uint256 amount = 10 ether;
      vm.expectRevert(
        abi.encodeWithSelector(IWrappedERC20PermissionedDeposit.NotDepositor.selector, alice)
      );
      wrappedCbETH.deposit(amount);
      vm.stopPrank();
    }

    function testSetDepositPermission() public {
      assertEq(wrappedCbETH.depositor(alice), false);

      wrappedCbETH.setDepositPermission(alice, true);
      assertEq(wrappedCbETH.depositor(alice), true);

      wrappedCbETH.setDepositPermission(alice, false);
      assertEq(wrappedCbETH.depositor(alice), false);
    }

    function _deposit(address account, uint256 depositAmount) internal {
      vm.startPrank(account);
      mockERC20.approve(address(wrappedCbETH), depositAmount);
      wrappedCbETH.deposit(depositAmount);
      vm.stopPrank();
    }

    function _withdraw(address account, uint256 withdrawAmount) internal {
      vm.startPrank(account);
      wrappedCbETH.withdraw(withdrawAmount);
      vm.stopPrank();
    }

    function testDeposit() public {
      wrappedCbETH.setDepositPermission(alice, true);

      uint256 amountUnderlyingBefore = mockERC20.balanceOf(alice);
      uint256 amountWrappedBefore = wrappedCbETH.balanceOf(alice);

      uint256 depositAmount = 10 ether;
      _deposit(alice, depositAmount);

      assertEq(mockERC20.balanceOf(alice), amountUnderlyingBefore - depositAmount);
      assertEq(wrappedCbETH.balanceOf(alice), amountWrappedBefore + depositAmount);
    }

    function testWithdraw() public {
      wrappedCbETH.setDepositPermission(alice, true);
      uint256 depositAmount = 10 ether;
      _deposit(alice, depositAmount);

      uint256 amountUnderlyingBefore = mockERC20.balanceOf(alice);
      uint256 amountWrappedBefore = wrappedCbETH.balanceOf(alice);

      uint256 withdrawAmount = depositAmount;
      _withdraw(alice, withdrawAmount);

      assertEq(mockERC20.balanceOf(alice), amountUnderlyingBefore + withdrawAmount);
      assertEq(wrappedCbETH.balanceOf(alice), amountWrappedBefore - withdrawAmount);
    }

    function testRecover() public {
      uint256 amount = 10 ether;

      vm.startPrank(alice);
      mockERC20.transfer(address(wrappedCbETH), amount);
      vm.stopPrank();

      assertEq(wrappedCbETH.totalSupply(), 0);
      assertEq(mockERC20.balanceOf(address(this)), 0); 
      assertEq(mockERC20.balanceOf(address(wrappedCbETH)), amount);

      wrappedCbETH.recover();
      assertEq(mockERC20.balanceOf(address(this)), amount);
    }
}