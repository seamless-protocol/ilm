// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { DeployHelperLib } from "../../script/deploy/DeployHelperLib.sol";
import { Swapper } from "../../src/swap/Swapper.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { Step } from "../../src/types/DataTypes.sol";
import { UniversalAerodromeAdapter } from
    "../../src/swap/adapter/UniversalAerodromeAdapter.sol";
import { IWrappedERC20PermissionedDeposit } from
    "../../src/interfaces/IWrappedERC20PermissionedDeposit.sol";
import { WrappedTokenAdapter } from
    "../../src/swap/adapter/WrappedTokenAdapter.sol";
import { TestConstants } from "../config/TestConstants.sol";

import "forge-std/console.sol";

contract UniversalAerodromeAdapterBackTest is Test, TestConstants {
    string internal BASE_RPC_URL = vm.envString("BASE_MAINNET_RPC_URL");

    LoopStrategy WETH_WSTETH =
        LoopStrategy(0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e);
    LoopStrategy WETH_USDC_LONG =
        LoopStrategy(0x2FB1bEa0a63F77eFa77619B903B2830b52eE78f4);
    Swapper swapper = Swapper(0xE314ae9D279919a00d4773cCe37946A98fADDaBc);

    IWrappedERC20PermissionedDeposit wrappedTokenWSTETH =
    IWrappedERC20PermissionedDeposit(0xc9ae3B5673341859D3aC55941D27C8Be4698C9e4);
    IWrappedERC20PermissionedDeposit wrappedTokenWETH =
    IWrappedERC20PermissionedDeposit(0x3e8707557D4aD25d6042f590bCF8A06071Da2c5F);

    WrappedTokenAdapter wrappedTokenAdapter =
        WrappedTokenAdapter(0xc3e17CDac7C6ED317f0D9845d47df1a281B5f79E);

    IERC20 USDC = IERC20(BASE_MAINNET_USDC);
    IERC20 WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 WSTETH = IERC20(BASE_MAINNET_WSTETH);

    int24 tickSpacingWETHUSDC = 100;
    int24 tickSpacingWETHWSTETH = 1;

    uint256 swapperOffsetFactor = 350000;

    uint256 WETH_USDC_LONG_REBALANCE_BLOCK = 14728506;
    uint256 WETH_WSTETH_REBALANCE_BLOCK = 15798959;

    function _deployAndSetupUniversalAerodromeAdapter() internal {
        UniversalAerodromeAdapter universalAerodromeAdapter =
            new UniversalAerodromeAdapter(SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS);

        vm.startPrank(SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS);
        universalAerodromeAdapter.setPath(USDC, WETH, tickSpacingWETHUSDC);
        universalAerodromeAdapter.setPath(WETH, WSTETH, tickSpacingWETHWSTETH);
        universalAerodromeAdapter.setSwapper(address(swapper));

        DeployHelperLib._setSwapperRouteBetweenWrappedAndToken(
            swapper,
            wrappedTokenWSTETH,
            WETH,
            wrappedTokenAdapter,
            universalAerodromeAdapter,
            swapperOffsetFactor
        );

        DeployHelperLib._setSwapperRouteBetweenWrappedAndToken(
            swapper,
            wrappedTokenWETH,
            USDC,
            wrappedTokenAdapter,
            universalAerodromeAdapter,
            swapperOffsetFactor
        );

        vm.stopPrank();
    }

    function test_rebalanceSucceeds_whenUsing_universalAerodromeAdapter_for_WETH_WSTETH_strategy(
    ) public {
        vm.createSelectFork(BASE_RPC_URL, WETH_WSTETH_REBALANCE_BLOCK);

        assertEq(WETH_WSTETH.rebalanceNeeded(), true);

        _deployAndSetupUniversalAerodromeAdapter();

        WETH_WSTETH.rebalance();

        assertEq(WETH_WSTETH.rebalanceNeeded(), false);
    }

    function test_rebalanceSuceeds_whenUsing_universalAerodromeAdapter_for_WETH_USDC_LONG_strategy(
    ) public {
        vm.createSelectFork(BASE_RPC_URL, WETH_USDC_LONG_REBALANCE_BLOCK);

        assertEq(WETH_USDC_LONG.rebalanceNeeded(), true);

        _deployAndSetupUniversalAerodromeAdapter();

        WETH_USDC_LONG.rebalance();

        assertEq(WETH_USDC_LONG.rebalanceNeeded(), false);
    }
}
