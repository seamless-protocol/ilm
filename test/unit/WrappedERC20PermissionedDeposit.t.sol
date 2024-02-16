// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IAccessControl } from
    "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    WrappedERC20PermissionedDeposit,
    IWrappedERC20PermissionedDeposit
} from "../../src/tokens/WrappedERC20PermissionedDeposit.sol";
import { MockERC20 } from "../mock/MockERC20.sol";

/// @title WrappedERC20PermissionedDepositTest
/// @notice Unit tests for the WrappedERC20PermissionedDeposit contract
contract WrappedERC20PermissionedDepositTest is Test {
    WrappedERC20PermissionedDeposit public wrappedToken;
    MockERC20 public mockERC20;

    address public alice = makeAddr("alice");

    function setUp() public {
        mockERC20 = new MockERC20("Mock", "M");
        wrappedToken =
        new WrappedERC20PermissionedDeposit("WrappedMock", "WM", IERC20(mockERC20), address(this));

        deal(address(mockERC20), address(alice), 100 ether);
    }

    /// @dev testing if owner and underlying token are set up correctly on the construction
    function test_setUp() public {
        assertEq(
            wrappedToken.hasRole(
                wrappedToken.DEFAULT_ADMIN_ROLE(), address(this)
            ),
            true
        );
        assertEq(address(wrappedToken.underlying()), address(mockERC20));
    }

    /// @dev test reverting if unpermissioned user try to deposit(wrap) the token
    function test_deposit_revertNotDepositor() public {
        vm.startPrank(alice);
        uint256 amount = 10 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                wrappedToken.DEPOSITOR_ROLE()
            )
        );
        wrappedToken.deposit(amount);
        vm.stopPrank();
    }

    /// @dev test confirming permissions for deposits are set and unset correctly
    function test_setDepositPermission() public {
        assertEq(
            wrappedToken.hasRole(wrappedToken.DEPOSITOR_ROLE(), alice), false
        );

        wrappedToken.grantRole(wrappedToken.DEPOSITOR_ROLE(), alice);
        assertEq(
            wrappedToken.hasRole(wrappedToken.DEPOSITOR_ROLE(), alice), true
        );

        wrappedToken.revokeRole(wrappedToken.DEPOSITOR_ROLE(), alice);
        assertEq(
            wrappedToken.hasRole(wrappedToken.DEPOSITOR_ROLE(), alice), false
        );
    }

    /// @dev test confirming that permissioned user can deposit and receive correct amount of wrapped token
    function test_deposit() public {
        wrappedToken.grantRole(wrappedToken.DEPOSITOR_ROLE(), alice);

        uint256 amountUnderlyingBefore = mockERC20.balanceOf(alice);
        uint256 amountWrappedBefore = wrappedToken.balanceOf(alice);

        uint256 depositAmount = 10 ether;
        _deposit(alice, depositAmount);

        assertEq(
            mockERC20.balanceOf(alice), amountUnderlyingBefore - depositAmount
        );
        assertEq(
            wrappedToken.balanceOf(alice), amountWrappedBefore + depositAmount
        );
    }

    /// @dev test confirming that anybody can withdraw (unwrap) and receive correct amount of underlying token
    function test_withdraw() public {
        wrappedToken.grantRole(wrappedToken.DEPOSITOR_ROLE(), alice);
        uint256 depositAmount = 10 ether;
        _deposit(alice, depositAmount);

        uint256 amountUnderlyingBefore = mockERC20.balanceOf(alice);
        uint256 amountWrappedBefore = wrappedToken.balanceOf(alice);

        uint256 withdrawAmount = depositAmount;
        _withdraw(alice, withdrawAmount);

        assertEq(
            mockERC20.balanceOf(alice), amountUnderlyingBefore + withdrawAmount
        );
        assertEq(
            wrappedToken.balanceOf(alice), amountWrappedBefore - withdrawAmount
        );

        // test if can withdraw without depositPermission
        _deposit(alice, depositAmount);
        wrappedToken.revokeRole(wrappedToken.DEPOSITOR_ROLE(), alice);
        _withdraw(alice, withdrawAmount);
        assertEq(
            mockERC20.balanceOf(alice), amountUnderlyingBefore + withdrawAmount
        );
        assertEq(
            wrappedToken.balanceOf(alice), amountWrappedBefore - withdrawAmount
        );
    }

    /// @dev test confirming that recovering of wrongly sent underlying tokens are possible by owner and receievs correct amount of underlying
    function test_recover() public {
        uint256 amount = 10 ether;

        vm.startPrank(alice);
        mockERC20.transfer(address(wrappedToken), amount);
        vm.stopPrank();

        assertEq(wrappedToken.totalSupply(), 0);
        assertEq(mockERC20.balanceOf(address(this)), 0);
        assertEq(mockERC20.balanceOf(address(wrappedToken)), amount);

        wrappedToken.recover();
        assertEq(mockERC20.balanceOf(address(this)), amount);
    }

    /// @dev test reverting when non admin try to recover wrongly sent underlying tokens to the contract
    function test_recover_revertNotAdmin() public {
        uint256 amount = 10 ether;
        vm.startPrank(alice);
        mockERC20.transfer(address(wrappedToken), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                wrappedToken.DEFAULT_ADMIN_ROLE()
            )
        );
        wrappedToken.recover();
        vm.stopPrank();
    }

    /// @dev depositing funds to the wrapper contract to get wrapped token
    function _deposit(address account, uint256 depositAmount) internal {
        vm.startPrank(account);
        mockERC20.approve(address(wrappedToken), depositAmount);
        wrappedToken.deposit(depositAmount);
        vm.stopPrank();
    }

    /// @dev withdrawing funds from the wrapper contract to unwrap the token and get underlying
    function _withdraw(address account, uint256 withdrawAmount) internal {
        vm.startPrank(account);
        wrappedToken.withdraw(withdrawAmount);
        vm.stopPrank();
    }
}
