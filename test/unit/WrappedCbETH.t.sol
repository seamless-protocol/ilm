// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {
    WrappedCbETH,
    IWrappedERC20PermissionedDeposit
} from "../../src/tokens/WrappedCbETH.sol";
import { MockERC20 } from "../mock/MockERC20.sol";

/// @title WrappedCbETHTest
/// @notice Unit tests for the WrappedCbETH contract
contract WrappedCbETHTest is Test {
    WrappedCbETH public wrappedCbETH;
    MockERC20 public mockERC20;

    address public alice = makeAddr("alice");

    function setUp() public {
        mockERC20 = new MockERC20("Mock", "M");
        wrappedCbETH =
        new WrappedCbETH("WrappedMock", "WM", IERC20(mockERC20), address(this));

        deal(address(mockERC20), address(alice), 100 ether);
    }

    /// @dev testing if owner and underlying token are set up correctly on the construction
    function test_setUp() public {
        assertEq(wrappedCbETH.owner(), address(this));
        assertEq(address(wrappedCbETH.underlying()), address(mockERC20));
    }

    /// @dev test reverting if unpermissioned user try to deposit(wrap) the token
    function test_deposit_revertNotDepositor() public {
        vm.startPrank(alice);
        uint256 amount = 10 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IWrappedERC20PermissionedDeposit.NotDepositor.selector, alice
            )
        );
        wrappedCbETH.deposit(amount);
        vm.stopPrank();
    }

    /// @dev test confirming permissions for deposits are set and unset correctly
    function test_setDepositPermission() public {
        assertEq(wrappedCbETH.depositor(alice), false);

        wrappedCbETH.setDepositPermission(alice, true);
        assertEq(wrappedCbETH.depositor(alice), true);

        wrappedCbETH.setDepositPermission(alice, false);
        assertEq(wrappedCbETH.depositor(alice), false);
    }

    /// @dev test confirming that permissioned user can deposit and receive correct amount of wrapped token
    function test_deposit() public {
        wrappedCbETH.setDepositPermission(alice, true);

        uint256 amountUnderlyingBefore = mockERC20.balanceOf(alice);
        uint256 amountWrappedBefore = wrappedCbETH.balanceOf(alice);

        uint256 depositAmount = 10 ether;
        _deposit(alice, depositAmount);

        assertEq(
            mockERC20.balanceOf(alice), amountUnderlyingBefore - depositAmount
        );
        assertEq(
            wrappedCbETH.balanceOf(alice), amountWrappedBefore + depositAmount
        );
    }

    /// @dev test confirming that anybody can withdraw (unwrap) and receive correct amount of underlying token
    function test_withdraw() public {
        wrappedCbETH.setDepositPermission(alice, true);
        uint256 depositAmount = 10 ether;
        _deposit(alice, depositAmount);

        uint256 amountUnderlyingBefore = mockERC20.balanceOf(alice);
        uint256 amountWrappedBefore = wrappedCbETH.balanceOf(alice);

        uint256 withdrawAmount = depositAmount;
        _withdraw(alice, withdrawAmount);

        assertEq(
            mockERC20.balanceOf(alice), amountUnderlyingBefore + withdrawAmount
        );
        assertEq(
            wrappedCbETH.balanceOf(alice), amountWrappedBefore - withdrawAmount
        );

        // test if can withdraw without depositPermission
        _deposit(alice, depositAmount);
        wrappedCbETH.setDepositPermission(alice, false);
        _withdraw(alice, withdrawAmount);
        assertEq(
            mockERC20.balanceOf(alice), amountUnderlyingBefore + withdrawAmount
        );
        assertEq(
            wrappedCbETH.balanceOf(alice), amountWrappedBefore - withdrawAmount
        );
    }

    /// @dev test confirming that recovering of wrongly sent underlying tokens are possible by owner and receievs correct amount of underlying
    function test_recover() public {
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

    /// @dev test reverting when non owner try to recover wrongly sent underlying tokens to the contract
    function test_recover_revertNotOwner() public {
        uint256 amount = 10 ether;
        vm.startPrank(alice);
        mockERC20.transfer(address(wrappedCbETH), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, address(alice)
            )
        );
        wrappedCbETH.recover();
        vm.stopPrank();
    }

    /// @dev depositing funds to the wrapper contract to get wrapped token
    function _deposit(address account, uint256 depositAmount) internal {
        vm.startPrank(account);
        mockERC20.approve(address(wrappedCbETH), depositAmount);
        wrappedCbETH.deposit(depositAmount);
        vm.stopPrank();
    }

    /// @dev withdrawing funds from the wrapper contract to unwrap the token and get underlying
    function _withdraw(address account, uint256 withdrawAmount) internal {
        vm.startPrank(account);
        wrappedCbETH.withdraw(withdrawAmount);
        vm.stopPrank();
    }
}
