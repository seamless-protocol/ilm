// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";

/// @title AdapterMock
/// @dev Mocks the behavior of the SwapAdapter contract
contract SwapAdapterMock is Test, ISwapAdapter {
    uint256 slippagePCT;

    /// @inheritdoc ISwapAdapter
    /// @dev the slippagePCT allows for setting some slippage
    /// @dev CRUCIAL: THIS FUNCTION IS NOT INTENDED TO ACCOUNT FOR ASSETS WITH DIFFERING DECIMALS
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount) {
        // transfer `from` tokens from sender
        from.transferFrom(msg.sender, address(this), fromAmount);

        // pretend there is no loss to slippage or DEX fees
        toAmount = fromAmount * (100 - slippagePCT) / 100;
        deal(address(to), beneficiary, to.balanceOf(beneficiary) + toAmount);
    }

    /// @inheritdoc ISwapAdapter
    function setSwapper(address swapper) external { }

    function setSlippagePCT(uint256 slippage) external {
        slippagePCT = slippage;
    }
}
