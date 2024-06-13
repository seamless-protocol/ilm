// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";
import { UniversalAerodromeAdapter } from
    "../../src/swap/adapter/UniversalAerodromeAdapter.sol";

contract UniversalAerodromeAdapterTest is BaseForkTest {
    event PathSet(IERC20 from, IERC20 to, bytes path);

    address OWNER = makeAddr("owner");
    address NON_OWNER = makeAddr("non-owner");
    address payable BENEFICIARY = payable(makeAddr("beneficiary"));
    address LARGEST_USDC_HOLDER = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;

    uint256 swapAmountUSDC = 100 * 10 ** 6;
    uint256 swapAmountWETH = 1 ether;

    int24 tickSpacingWETHUSDC = 100;

    UniversalAerodromeAdapter adapter;
    IERC20 USDC = IERC20(BASE_MAINNET_USDC);
    IERC20 WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 TEST_COIN = IERC20(makeAddr("test-coin"));

    function setUp() public {
        baseFork = vm.createSelectFork(BASE_RPC_URL, 15555784);

        deal(BASE_MAINNET_WETH, OWNER, 1000 ether);
        vm.startPrank(LARGEST_USDC_HOLDER);
        USDC.transfer(OWNER, 1000 * 10 ** 6);
        vm.stopPrank();

        adapter = new UniversalAerodromeAdapter(OWNER);

        vm.startPrank(OWNER);
        adapter.setPath(USDC, WETH, tickSpacingWETHUSDC);
        adapter.setSwapper(OWNER);
        vm.stopPrank();
    }

    function test_setUp() public {
        assertEq(adapter.owner(), OWNER);
        assertEq(WETH.balanceOf(OWNER), 1000 ether);
        assertEq(USDC.balanceOf(OWNER), 1000 * 10 ** 6);
    }

    function test_executeSwap_swapsAllTokensSentToAdapter_andSendsReceivedTokens_toBeneficiary(
    ) public {
        assertEq(WETH.balanceOf(address(adapter)), 0);
        assertEq(USDC.balanceOf(address(adapter)), 0);

        vm.startPrank(OWNER);
        USDC.approve(address(adapter), swapAmountUSDC);
        uint256 amountReceived =
            adapter.executeSwap(USDC, WETH, swapAmountUSDC, BENEFICIARY);
        vm.stopPrank();

        assertGt(amountReceived, 0);
        assertEq(WETH.balanceOf(address(adapter)), 0);
        assertEq(USDC.balanceOf(address(adapter)), 0);
    }

    function test_executeSwap_transfersAllReceivedTokens_toBeneficiary()
        public
    {
        uint256 oldBalance = WETH.balanceOf(BENEFICIARY);

        vm.startPrank(OWNER);
        USDC.approve(address(adapter), swapAmountUSDC);
        uint256 amountReceived =
            adapter.executeSwap(USDC, WETH, swapAmountUSDC, BENEFICIARY);
        vm.stopPrank();

        assertEq(amountReceived, WETH.balanceOf(BENEFICIARY) - oldBalance);
    }

    function test_setSwapper_revertsIf_callerIsNotOwner() public {
        vm.prank(NON_OWNER);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        adapter.setSwapper(NON_OWNER);
    }

    function test_setPath_setsNewPath_andEmits_PathSetEvent() public {
        bytes memory expectedPath = abi.encodePacked(
            address(TEST_COIN), tickSpacingWETHUSDC, address(WETH)
        );
        vm.startPrank(OWNER);
        vm.expectEmit();

        emit PathSet(TEST_COIN, WETH, expectedPath);

        adapter.setPath(TEST_COIN, WETH, tickSpacingWETHUSDC);
        vm.stopPrank();

        assertEq(adapter.swapPaths(TEST_COIN, WETH), expectedPath);
        assertEq(adapter.swapPaths(WETH, TEST_COIN), expectedPath);
    }

    function test_setPath_revertsIf_calledIsNotOwner() public {
        vm.prank(NON_OWNER);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                NON_OWNER
            )
        );

        adapter.setPath(TEST_COIN, WETH, tickSpacingWETHUSDC);
    }
}
