// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { MockERC20 } from "../mock/MockERC20.sol";
import { BaseForkTest } from "../BaseForkTest.t.sol";
import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";
import { IWrappedERC20PermissionedDeposit } from
    "../../src/interfaces/IWrappedERC20PermissionedDeposit.sol";
import { WrappedERC20PermissionedDeposit } from
    "../../src/tokens/WrappedERC20PermissionedDeposit.sol";
import { WrappedTokenAdapter } from
    "../../src/swap/adapter/WrappedTokenAdapter.sol";

/// @title WrappedTokenAdapterTest
/// @notice Unit tests for the WrappedTokenAdapter contract
contract WrappedTokenAdapterTest is BaseForkTest {
    ///////////////////////////////////
    //////// REPLICATED EVENTS ////////
    ///////////////////////////////////

    /// @notice emitted when the wrapper contract for a given WrappedToken is set
    /// @param from token to perform wrapping/unwrapping on
    /// @param to token which will be received after wrapping/unwrapping
    /// @param wrapper WrappedERC20PermissionedDeposit contract
    event WrapperSet(
        IERC20 from, IERC20 to, IWrappedERC20PermissionedDeposit wrapper
    );

    /// @notice emitted when the wrapper contract for a given WrappedToken is removed
    /// @param from token to perform wrapping/unwrapping on
    /// @param to token which will be received after wrapping/unwrapping
    event WrapperRemoved(IERC20 from, IERC20 to);

    uint256 swapAmount = 1 ether;
    address alice = makeAddr("alice");
    address public OWNER = makeAddr("OWNER");
    address public NON_OWNER = makeAddr("NON_OWNER");

    WrappedTokenAdapter adapter;
    WrappedERC20PermissionedDeposit public wrappedToken;
    MockERC20 public mockERC20;

    /// @dev initializes adapter, wrappedCbeTH and mockERC20, as
    /// well as setting deposit permission for the adapter on the
    /// WrappedERC20PermissionedDeposit contract
    function setUp() public {
        adapter = new WrappedTokenAdapter(OWNER, alice);

        mockERC20 = new MockERC20("Mock", "M");
        wrappedToken =
        new WrappedERC20PermissionedDeposit("WrappedMock", "WM", IERC20(mockERC20), OWNER);

        deal(address(mockERC20), address(alice), 100 ether);

        vm.startPrank(OWNER);
        wrappedToken.grantRole(wrappedToken.DEPOSITOR_ROLE(), address(adapter));
        vm.stopPrank();
    }

    /// @dev ensures swapping from underlying token to wrapped token returns
    /// the same amount as swapped but in wrapped form
    function test_executeSwap_wrapsFromToken_whenFromTokenIsUnderlying()
        public
    {
        uint256 oldFromBalance = mockERC20.balanceOf(alice);
        uint256 oldToBalance = wrappedToken.balanceOf(alice);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);

        vm.prank(alice);
        mockERC20.approve(address(adapter), swapAmount);

        vm.prank(alice);
        uint256 toAmount = adapter.executeSwap(
            mockERC20, wrappedToken, swapAmount, payable(alice)
        );

        uint256 newFromBalance = mockERC20.balanceOf(alice);
        uint256 newToBalance = wrappedToken.balanceOf(alice);

        assertEq(oldFromBalance - newFromBalance, swapAmount);
        assertEq(newToBalance - oldToBalance, swapAmount);
        assertEq(toAmount, swapAmount);
    }

    /// @dev ensures swapping from wrapped token to underlying token returns
    /// the same amount as swapped but in underlying form
    function test_executeSwap_unwrapsFromToken_whenFromTokenIsNotUnderlying()
        public
    {
        uint256 oldFromBalance = mockERC20.balanceOf(alice);
        uint256 oldToBalance = wrappedToken.balanceOf(alice);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);

        vm.prank(alice);
        mockERC20.approve(address(adapter), swapAmount);

        vm.prank(alice);
        uint256 toAmount = adapter.executeSwap(
            mockERC20, wrappedToken, swapAmount, payable(alice)
        );

        uint256 newFromBalance = mockERC20.balanceOf(alice);
        uint256 newToBalance = wrappedToken.balanceOf(alice);

        assertEq(oldFromBalance - newFromBalance, swapAmount);

        assertEq(newToBalance - oldToBalance, swapAmount);
        assertEq(toAmount, swapAmount);

        oldFromBalance = wrappedToken.balanceOf(alice);
        oldToBalance = mockERC20.balanceOf(alice);

        vm.prank(alice);
        wrappedToken.approve(address(adapter), swapAmount);

        vm.prank(alice);
        toAmount = adapter.executeSwap(
            wrappedToken, mockERC20, swapAmount, payable(alice)
        );

        newFromBalance = wrappedToken.balanceOf(alice);
        newToBalance = mockERC20.balanceOf(alice);

        assertEq(oldFromBalance - newFromBalance, swapAmount);
        assertEq(newToBalance - oldToBalance, swapAmount);
        assertEq(toAmount, swapAmount);
    }

    /// @dev ensures that executeSwap call reverts is the caller is not a whitelisted
    /// swapper
    function test_executeSwap_revertsWhen_callerIsNotSwapper() public {
        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);
        vm.prank(OWNER);
        adapter.setSwapper(OWNER);

        vm.prank(alice);
        mockERC20.approve(address(adapter), swapAmount);

        vm.expectRevert(ISwapAdapter.NotSwapper.selector);

        vm.prank(alice);
        adapter.executeSwap(mockERC20, wrappedToken, swapAmount, payable(alice));
    }

    /// @dev ensures that setting a wrapper will set it for both orderings (from, to) and (to,from)
    /// in mapping, and emits the associated events
    function test_setWrapper_setsWrapperForBothTokenOrderings_and_emitsWrapperSetEvents(
    ) public {
        address wrapper = address(adapter.wrappers(mockERC20, wrappedToken));

        assertEq(wrapper, address(0));

        vm.expectEmit();
        emit WrapperSet(mockERC20, wrappedToken, wrappedToken);
        vm.expectEmit();
        emit WrapperSet(wrappedToken, mockERC20, wrappedToken);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);

        address wrapperFromTo =
            address(adapter.wrappers(mockERC20, wrappedToken));
        address wrapperToFrom =
            address(adapter.wrappers(wrappedToken, mockERC20));

        assertEq(wrapperFromTo, wrapperToFrom);
        assertEq(wrapperFromTo, address(wrappedToken));
        assertEq(wrapperToFrom, address(wrappedToken));
    }

    /// @dev ensures that setting a wrapper will remove any previously set wrappers
    function test_setWrapper_removesPreviouslySetWrappers() public {
        address wrapper = address(adapter.wrappers(mockERC20, wrappedToken));

        assertEq(wrapper, address(0));

        vm.expectEmit();
        emit WrapperSet(mockERC20, wrappedToken, wrappedToken);
        vm.expectEmit();
        emit WrapperSet(wrappedToken, mockERC20, wrappedToken);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);

        address wrapperFromTo =
            address(adapter.wrappers(mockERC20, wrappedToken));
        address wrapperToFrom =
            address(adapter.wrappers(wrappedToken, mockERC20));

        assertEq(wrapperFromTo, wrapperToFrom);
        assertEq(wrapperFromTo, address(wrappedToken));
        assertEq(wrapperToFrom, address(wrappedToken));

        vm.expectEmit();
        emit WrapperRemoved(mockERC20, wrappedToken);
        vm.expectEmit();
        emit WrapperRemoved(wrappedToken, mockERC20);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);
    }

    /// @dev ensures that setting a wrapper will revert when called by non-owner
    function test_setWrapper_revertsWhen_callerIsNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        vm.prank(NON_OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);
    }

    /// @dev ensures that removing a wrapper will remove the wrapper set for both
    /// token orderings (from, to) and (to, from) in mapping, and emit associated
    /// events
    function test_removeWrapper_removesPreviouslySetWrapperBothTokenOrderings_and_emitsWrapperRemovedEvent(
    ) public {
        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedToken, wrappedToken);

        vm.expectEmit();
        emit WrapperRemoved(mockERC20, wrappedToken);
        vm.expectEmit();
        emit WrapperRemoved(wrappedToken, mockERC20);

        vm.prank(OWNER);
        adapter.removeWrapper(mockERC20, wrappedToken);

        address wrapperFromTo =
            address(adapter.wrappers(mockERC20, wrappedToken));
        address wrapperToFrom =
            address(adapter.wrappers(wrappedToken, mockERC20));

        assertEq(wrapperFromTo, address(0));

        assertEq(wrapperToFrom, address(0));
    }

    /// @dev ensures that removing a wrapper will revert if called by a
    /// non-owner
    function test_removeWrapper_revertsWhen_callerIsNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        vm.prank(NON_OWNER);
        adapter.removeWrapper(mockERC20, wrappedToken);
    }

    /// @dev ensures that setSwapper call reverts when calls is not owner
    function test_setSwapper_revertsWhen_callerIsNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        vm.prank(NON_OWNER);
        adapter.setSwapper(NON_OWNER);
    }
}
