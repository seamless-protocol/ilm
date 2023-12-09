// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { AerodromeAdapter } from "../../src/swap/adapter/AerodromeAdapter.sol";
import { IRouter } from "../../src/vendor/aerodrome/IRouter.sol";

/// @title AerodromeAdapterTEst
/// @notice Unit tests for the AerodromeAdapter contract
contract AerodromeAdapterTest is BaseForkTest {
    IERC20 public WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public CbETH = IERC20(BASE_MAINNET_CbETH);

    uint256 swapAmount = 1 ether;
    address alice = makeAddr("alice");
    address public OWNER = makeAddr("OWNER");

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
}
