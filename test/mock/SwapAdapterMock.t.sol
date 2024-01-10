// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";

/// @title AdapterMock
/// @dev Mocks the behavior of the SwapAdapter contract
contract SwapAdapterMock is Test, ISwapAdapter {
    address SILENCER = makeAddr("silencer");

    /// @inheritdoc ISwapAdapter
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount) {
        // transfer `from` tokens from sender
        from.transferFrom(msg.sender, address(this), fromAmount);

        // pretend there is no loss to slippage or DEX fees
        toAmount = fromAmount;
        deal(address(to), beneficiary, to.balanceOf(beneficiary) + toAmount);
    }

    /// @inheritdoc ISwapAdapter
    function setSwapper(address swapper) external { }

    /// @inheritdoc ISwapAdapter
    function getSwapper() external view returns (address swapper) {
        return SILENCER;
    }
}
