// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { SwapAdapterMock } from "../mock/SwapAdapterMock.t.sol";
import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { Step } from "../../src/types/DataTypes.sol";
import { Swapper } from "../../src/swap/Swapper.sol";

/// @notice Unit tests for the Swapper contract
/// @dev assuming that `BASE_MAINNET_RPC_URL` is set in the `.env`
contract SwapperTest is BaseForkTest {
    ///////////////////////////////////
    //////// REPLICATED EVENTS ////////
    ///////////////////////////////////

    /// @notice emitted when a route is set for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param steps array of Step structs needed to perform swap
    event RouteSet(IERC20 indexed from, IERC20 indexed to, Step[] steps);

    /// @notice emitted when the offsetFactor of a route is set for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param offsetUSD offsetFactor from 0 - 1e8
    event OffsetFactorSet(
        IERC20 indexed from, IERC20 indexed to, uint256 offsetUSD
    );

    /// @notice emitted when a route is removed
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    event RouteRemoved(IERC20 indexed from, IERC20 indexed to);

    /// @notice emitted when a strategy is added to strategies enumerable set
    /// @param strategy address of added strategy
    event StrategyAdded(address strategy);

    /// @notice emitted when a strategy is removed from strategies enumerable set
    /// @param strategy address of added strategy
    event StrategyRemoved(address strategy);

    Swapper swapper;
    ISwapAdapter wethCbETHAdapter;
    ISwapAdapter CbETHUSDbCAdapter;

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);

    address public OWNER = makeAddr("OWNER");
    address public NON_OWNER = makeAddr("NON_OWNER");
    address public ALICE = makeAddr("ALICE");

    /// @dev sets up context for testing swapper contract
    function setUp() public {
        // deploy two mock swap adapters
        wethCbETHAdapter = new SwapAdapterMock();
        CbETHUSDbCAdapter = new SwapAdapterMock();

        // deploy and initiliaze swapper
        swapper = new Swapper();
        swapper.Swapper_init(OWNER);

        vm.startPrank(OWNER);
        swapper.grantRole(swapper.MANAGER_ROLE(), OWNER);
        vm.stopPrank();

        // fake minting some tokens to start with
        deal(address(WETH), address(this), 100 ether);
    }

    /// @dev ensures that a new route is set
    function test_setRoute_setsNewRoute() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.expectEmit();
        emit RouteSet(WETH, USDbC, steps);

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        Step[] memory actualSteps = swapper.getRoute(WETH, USDbC);

        for (uint256 i; i < actualSteps.length; ++i) {
            assert(address(steps[i].from) == address(actualSteps[i].from));
            assert(address(steps[i].to) == address(actualSteps[i].to));
            assert(address(steps[i].adapter) == address(actualSteps[i].adapter));
        }
    }

    /// @dev checks that the `RouteRemoved` event is emitted prior to setting a
    /// route which previously had been set, to ensure the route was removed
    /// before setting the new one
    function test_setRoute_removesOldRoutePriorToSettingNewRoute() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        vm.expectEmit();
        emit RouteRemoved(WETH, USDbC);

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);
    }

    /// @dev ensures reversion when an adapter address is the zero-address
    function test_setRoute_revertsWhen_adapterIsZeroAddress() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] =
            Step({ from: CbETH, to: USDbC, adapter: ISwapAdapter(address(0)) });

        vm.expectRevert(ISwapper.InvalidAddress.selector);

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);
    }

    /// @dev ensures that an existing route is removed
    function test_removeRoute_removesExistingRoute() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        vm.expectEmit();
        emit RouteRemoved(WETH, USDbC);

        vm.prank(OWNER);
        swapper.removeRoute(WETH, USDbC);

        Step[] memory routeSteps = swapper.getRoute(WETH, USDbC);

        assertEq(routeSteps.length, 0);
    }

    /// @dev ensures call is reverts if caller is not owner
    function test_removeRoute_revertsWhen_callerIsNotOwner() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NON_OWNER,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NON_OWNER);
        swapper.removeRoute(WETH, USDbC);
    }

    /// @dev ensures that a new offsetFactor is set
    function test_setOffsetFactor_setsNewOffsetFactor() public {
        uint256 newOffsetFactor = 1e7;

        vm.expectEmit();
        emit OffsetFactorSet(WETH, USDbC, newOffsetFactor);

        vm.prank(OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);

        uint256 actualOffsetFactor = swapper.offsetFactor(WETH, USDbC);

        assertEq(newOffsetFactor, actualOffsetFactor);
    }

    /// @dev ensures call reverts when the new offsetFactor is outside the range
    function test_setOffsetFactor_revertsWhen_NewOffsetFactorIsOutsideRange()
        public
    {
        uint256 newOffsetFactor = 1 ether;

        vm.expectRevert(ISwapper.OffsetOutsideRange.selector);

        vm.prank(OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);

        newOffsetFactor = 0;

        vm.expectRevert(ISwapper.OffsetOutsideRange.selector);

        vm.prank(OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);
    }

    /// @dev ensures call reverts when called by non-owner
    function test_setOffsetFactor_revertsWhen_calledByNonOwner() public {
        uint256 newOffsetFactor = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NON_OWNER,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NON_OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);
    }

    /// @dev ensures swapping works for a route with a single step
    function test_swap_performsSwap_SingleStep() public {
        Step[] memory steps = new Step[](1);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        vm.startPrank(OWNER);
        swapper.setRoute(WETH, CbETH, steps);
        swapper.grantRole(swapper.STRATEGY_ROLE(), ALICE);
        vm.stopPrank();

        uint256 swapAmount = 1 ether;

        deal(address(WETH), ALICE, WETH.balanceOf(ALICE) + 10 * swapAmount);

        vm.startPrank(ALICE);
        WETH.approve(address(swapper), swapAmount);

        uint256 oldWETHBalance = WETH.balanceOf(ALICE);
        uint256 oldCbETHBalance = CbETH.balanceOf(ALICE);

        swapper.swap(WETH, CbETH, swapAmount, payable(ALICE));

        assertEq(oldWETHBalance - WETH.balanceOf(ALICE), swapAmount);
        assertEq(CbETH.balanceOf(ALICE) - oldCbETHBalance, swapAmount);
    }

    /// @dev ensures swapping works for a route with multiple steps
    function test_swap_performsSwap_MultipleSteps() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.startPrank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);
        swapper.grantRole(swapper.STRATEGY_ROLE(), ALICE);
        vm.stopPrank();

        uint256 swapAmount = 1 ether;

        deal(address(WETH), ALICE, WETH.balanceOf(ALICE) + 10 * swapAmount);

        vm.startPrank(ALICE);
        WETH.approve(address(swapper), swapAmount);

        uint256 oldWETHBalance = WETH.balanceOf(ALICE);
        uint256 oldUSDbCBalance = USDbC.balanceOf(ALICE);

        swapper.swap(WETH, USDbC, swapAmount, payable(ALICE));

        assertEq(oldWETHBalance - WETH.balanceOf(ALICE), swapAmount);
        assertEq(USDbC.balanceOf(ALICE) - oldUSDbCBalance, swapAmount);
    }
}
