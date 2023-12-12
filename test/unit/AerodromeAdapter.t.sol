// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { AerodromeAdapter } from "../../src/swap/adapter/AerodromeAdapter.sol";
import { IRouter } from "../../src/vendor/aerodrome/IRouter.sol";

/// @title AerodromeAdapterTEst
/// @notice Unit tests for the AerodromeAdapter contract
contract AerodromeAdapterTest is BaseForkTest {
    ///////////////////////////////////
    //////// REPLICATED EVENTS ////////
    ///////////////////////////////////

    /// @notice emitted when a value whether a pool is stable or not is set
    /// @param from first token of the pool
    /// @param to second token of the pool
    /// @param status boolean value indicating pool stability
    event IsPoolStableSet(IERC20 from, IERC20 to, bool status);

    /// @notice emitted when the poolFactory address is set
    /// @param factory address of poolFactory
    event PoolFactorySet(address factory);

    /// @notice emitted when the router address is set
    /// @param router address of router
    event RouterSet(address router);

    /// @notice emitted when set routes for a given swap are removed
    /// @param from address to swap from
    /// @param to addrses to swap to
    event RoutesRemoved(IERC20 from, IERC20 to);

    /// @notice emitted when the swap routes for a token pair are set
    /// @param from first token of the pool
    /// @param to second token of the pool
    /// @param routes array of routes for swap
    event RoutesSet(IERC20 from, IERC20 to, IRouter.Route[] routes);

    IERC20 public WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public CbETH = IERC20(BASE_MAINNET_CbETH);

    uint256 swapAmount = 1 ether;
    address alice = makeAddr("alice");
    address public OWNER = makeAddr("OWNER");
    address public NON_OWNER = makeAddr("NON_OWNER");

    AerodromeAdapter adapter;

    function setUp() public {
        adapter = new AerodromeAdapter();

        adapter.AerodromeAdapter__Init(
            OWNER, AERODROME_ROUTER, AERODROME_FACTORY
        );

        deal(address(WETH), address(alice), 100 ether);
    }

    function test_executeSwap() public {
        uint256 oldBalance = CbETH.balanceOf(alice);

        IRouter.Route[] memory routes = new IRouter.Route[](1);

        routes[0] = IRouter.Route({
            from: address(WETH),
            to: address(CbETH),
            stable: false,
            factory: AERODROME_FACTORY
        });

        vm.prank(OWNER);
        adapter.setRoutes(WETH, CbETH, routes);

        vm.prank(alice);
        WETH.approve(address(adapter), swapAmount);

        vm.prank(alice);
        uint256 receivedCbETH =
            adapter.executeSwap(WETH, CbETH, swapAmount, payable(alice));
        uint256 newBalance = CbETH.balanceOf(alice);

        assertEq(newBalance - oldBalance, receivedCbETH);
    }

    function test_setRoutes_setsRoutesForASwap_and_emitsRoutesSetEvent()
        public
    {
        assertEq(adapter.getSwapRoutes(WETH, CbETH).length, 0);

        IRouter.Route[] memory routes = new IRouter.Route[](1);

        routes[0] = IRouter.Route({
            from: address(WETH),
            to: address(CbETH),
            stable: false,
            factory: AERODROME_FACTORY
        });

        vm.prank(OWNER);

        vm.expectEmit();
        emit RoutesSet(WETH, CbETH, routes);

        adapter.setRoutes(WETH, CbETH, routes);
    }

    function test_setRoutes_deletsPreviousRoute_and_setsRoutesForASwap()
        public
    {
        assertEq(adapter.getSwapRoutes(WETH, CbETH).length, 0);

        IRouter.Route[] memory routes = new IRouter.Route[](1);

        routes[0] = IRouter.Route({
            from: address(WETH),
            to: address(CbETH),
            stable: false,
            factory: AERODROME_FACTORY
        });

        vm.prank(OWNER);
        adapter.setRoutes(WETH, CbETH, routes);

        vm.prank(OWNER);

        vm.expectEmit();
        emit RoutesRemoved(WETH, CbETH);

        adapter.setRoutes(WETH, CbETH, routes);
    }

    function test_setRoutes_revertsWhen_calledByNonOwner() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);

        routes[0] = IRouter.Route({
            from: address(WETH),
            to: address(CbETH),
            stable: false,
            factory: AERODROME_FACTORY
        });

        vm.prank(NON_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );
        adapter.setRoutes(WETH, CbETH, routes);
    }

    function test_removeRoutes_removesPreviouslySetRoutes_and_emitsRoutesRemovesEvent(
    ) public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);

        routes[0] = IRouter.Route({
            from: address(WETH),
            to: address(CbETH),
            stable: false,
            factory: AERODROME_FACTORY
        });

        vm.prank(OWNER);
        adapter.setRoutes(WETH, CbETH, routes);

        assertEq(adapter.getSwapRoutes(WETH, CbETH).length, 1);

        vm.prank(OWNER);

        vm.expectEmit();
        emit RoutesRemoved(WETH, CbETH);

        adapter.removeRoutes(WETH, CbETH);

        assertEq(adapter.getSwapRoutes(WETH, CbETH).length, 0);
    }

    function test_removeRoutes_revertsWhen_calledByNonOwner() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);

        routes[0] = IRouter.Route({
            from: address(WETH),
            to: address(CbETH),
            stable: false,
            factory: AERODROME_FACTORY
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        vm.prank(NON_OWNER);
        adapter.setRoutes(WETH, CbETH, routes);
    }

    function test_setIsPoolStable_setsValueForIsPoolStableForGivenTokens_andEmitsIsPoolStableSetEvent(
    ) public {
        assertEq(adapter.getIsPoolStable(WETH, CbETH), false);

        vm.prank(OWNER);

        vm.expectEmit();
        emit IsPoolStableSet(WETH, CbETH, true);

        adapter.setIsPoolStable(WETH, CbETH, true);

        assertEq(adapter.getIsPoolStable(WETH, CbETH), true);
    }

    function test_setIsPoolStable_revertsWhen_CallerIsNotOwner() public {
        vm.prank(NON_OWNER);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        adapter.setIsPoolStable(WETH, CbETH, true);
    }

    function test_setRouter_setAddressForRouter_andEmitsRouterSetEvent()
        public
    {
        assertEq(adapter.getRouter(), AERODROME_ROUTER);

        vm.prank(OWNER);

        vm.expectEmit();
        emit RouterSet(OWNER);

        adapter.setRouter(OWNER);
    }

    function test_setRouter_revertsWhen_CallerIsNotOwner() public {
        vm.prank(NON_OWNER);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        adapter.setRouter(OWNER);
    }

    function test_setPoolFactory_setAddressForPoolFactory_andEmitsPoolFactorySetEvent(
    ) public {
        assertEq(adapter.getPoolFactory(), AERODROME_FACTORY);

        vm.prank(OWNER);

        vm.expectEmit();
        emit PoolFactorySet(OWNER);

        adapter.setPoolFactory(OWNER);
    }

    function test_setPoolFactory_revertsWhen_CallerIsNotOwner() public {
        vm.prank(NON_OWNER);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        adapter.setPoolFactory(OWNER);
    }
}
