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
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
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
    WrappedCbETH public wrappedCbETH;
    MockERC20 public mockERC20;

    /// @dev initializes adapter, wrappedCbeTH and mockERC20, as
    /// well as setting deposit permission for the adapter on the
    /// wrappedCbETH contract
    function setUp() public {
        adapter = new WrappedTokenAdapter();

        adapter.WrappedTokenAdapter__Init(OWNER);

        mockERC20 = new MockERC20("Mock", "M");
        wrappedCbETH =
            new WrappedCbETH("WrappedMock", "WM", IERC20(mockERC20), OWNER);

        deal(address(mockERC20), address(alice), 100 ether);

        vm.prank(OWNER);
        wrappedCbETH.setDepositPermission(address(adapter), true);
    }

    /// @dev ensures swapping from underlying token to wrapped token returns
    /// the same amount as swapped but in wrapped form
    function test_executeSwap_wrapsFromToken_whenFromTokenIsUnderlying()
        public
    {
        uint256 oldFromBalance = mockERC20.balanceOf(alice);
        uint256 oldToBalance = wrappedCbETH.balanceOf(alice);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);
        vm.prank(OWNER);
        adapter.setSwapper(alice);

        vm.prank(alice);
        mockERC20.approve(address(adapter), swapAmount);

        vm.prank(alice);
        uint256 toAmount = adapter.executeSwap(
            mockERC20, wrappedCbETH, swapAmount, payable(alice)
        );

        uint256 newFromBalance = mockERC20.balanceOf(alice);
        uint256 newToBalance = wrappedCbETH.balanceOf(alice);

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
        uint256 oldToBalance = wrappedCbETH.balanceOf(alice);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);
        vm.prank(OWNER);
        adapter.setSwapper(alice);

        vm.prank(alice);
        mockERC20.approve(address(adapter), swapAmount);

        vm.prank(alice);
        uint256 toAmount = adapter.executeSwap(
            mockERC20, wrappedCbETH, swapAmount, payable(alice)
        );

        uint256 newFromBalance = mockERC20.balanceOf(alice);
        uint256 newToBalance = wrappedCbETH.balanceOf(alice);

        assertEq(oldFromBalance - newFromBalance, swapAmount);

        assertEq(newToBalance - oldToBalance, swapAmount);
        assertEq(toAmount, swapAmount);

        oldFromBalance = wrappedCbETH.balanceOf(alice);
        oldToBalance = mockERC20.balanceOf(alice);

        vm.prank(alice);
        wrappedCbETH.approve(address(adapter), swapAmount);

        vm.prank(alice);
        toAmount = adapter.executeSwap(
            wrappedCbETH, mockERC20, swapAmount, payable(alice)
        );

        newFromBalance = wrappedCbETH.balanceOf(alice);
        newToBalance = mockERC20.balanceOf(alice);

        assertEq(oldFromBalance - newFromBalance, swapAmount);
        assertEq(newToBalance - oldToBalance, swapAmount);
        assertEq(toAmount, swapAmount);
    }

    /// @dev ensures that executeSwap call reverts is the caller is not a whitelisted
    /// swapper
    function test_executeSwap_revertsWhen_callerIsNotSwapper() public {
        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);

        vm.prank(alice);
        mockERC20.approve(address(adapter), swapAmount);

        vm.expectRevert(ISwapAdapter.NotSwapper.selector);

        vm.prank(alice);
        adapter.executeSwap(mockERC20, wrappedCbETH, swapAmount, payable(alice));
    }

    /// @dev ensures that setting a wrapper will set it for both orderings (from, to) and (to,from)
    /// in mapping, and emits the associated events
    function test_setWrapper_setsWrapperForBothTokenOrderings_and_emitsWrapperSetEvents(
    ) public {
        address wrapper = address(adapter.getWrapper(mockERC20, wrappedCbETH));

        assertEq(wrapper, address(0));

        vm.expectEmit();
        emit WrapperSet(mockERC20, wrappedCbETH, wrappedCbETH);
        vm.expectEmit();
        emit WrapperSet(wrappedCbETH, mockERC20, wrappedCbETH);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);

        address wrapperFromTo =
            address(adapter.getWrapper(mockERC20, wrappedCbETH));
        address wrapperToFrom =
            address(adapter.getWrapper(wrappedCbETH, mockERC20));

        assertEq(wrapperFromTo, wrapperToFrom);
        assertEq(wrapperFromTo, address(wrappedCbETH));
        assertEq(wrapperToFrom, address(wrappedCbETH));
    }

    /// @dev ensures that setting a wrapper will remove any previously set wrappers
    function test_setWrapper_removesPreviouslySetWrappers() public {
        address wrapper = address(adapter.getWrapper(mockERC20, wrappedCbETH));

        assertEq(wrapper, address(0));

        vm.expectEmit();
        emit WrapperSet(mockERC20, wrappedCbETH, wrappedCbETH);
        vm.expectEmit();
        emit WrapperSet(wrappedCbETH, mockERC20, wrappedCbETH);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);

        address wrapperFromTo =
            address(adapter.getWrapper(mockERC20, wrappedCbETH));
        address wrapperToFrom =
            address(adapter.getWrapper(wrappedCbETH, mockERC20));

        assertEq(wrapperFromTo, wrapperToFrom);
        assertEq(wrapperFromTo, address(wrappedCbETH));
        assertEq(wrapperToFrom, address(wrappedCbETH));

        vm.expectEmit();
        emit WrapperRemoved(mockERC20, wrappedCbETH);
        vm.expectEmit();
        emit WrapperRemoved(wrappedCbETH, mockERC20);

        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);
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
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);
    }

    /// @dev ensures that removing a wrapper will remove the wrapper set for both
    /// token orderings (from, to) and (to, from) in mapping, and emit associated
    /// events
    function test_removeWrapper_removesPreviouslySetWrapperBothTokenOrderings_and_emitsWrapperRemovedEvent(
    ) public {
        vm.prank(OWNER);
        adapter.setWrapper(mockERC20, wrappedCbETH, wrappedCbETH);

        vm.expectEmit();
        emit WrapperRemoved(mockERC20, wrappedCbETH);
        vm.expectEmit();
        emit WrapperRemoved(wrappedCbETH, mockERC20);

        vm.prank(OWNER);
        adapter.removeWrapper(mockERC20, wrappedCbETH);

        address wrapperFromTo =
            address(adapter.getWrapper(mockERC20, wrappedCbETH));
        address wrapperToFrom =
            address(adapter.getWrapper(wrappedCbETH, mockERC20));

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
        adapter.removeWrapper(mockERC20, wrappedCbETH);
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
