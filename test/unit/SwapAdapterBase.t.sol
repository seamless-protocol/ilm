// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { BaseForkTest } from "../BaseForkTest.t.sol";

import { SwapAdapterBaseHarness } from "../mock/SwapAdapterBaseHarness.sol";

/// @title SwapAdapterBase
/// @notice Unit tests for the SwapAdapterBase contract
contract SwapAdapterBase is BaseForkTest {
    ///////////////////////////////////
    //////// REPLICATED EVENTS ////////
    ///////////////////////////////////

    /// @notice emitted when the Swapper contract is set for a given adapter
    /// @param swapper address of Swapper contract
    event SwapperSet(address swapper);

    address newSwapper = makeAddr("newSwapper");
    address owner = makeAddr("owner");

    SwapAdapterBaseHarness adapter;

    function setUp() public {
        adapter = new SwapAdapterBaseHarness(owner);
    }

    function test_expoedSetSwapper_newSwapperAddressIsSet_and_SwapperSetEventIsEmitted(
    ) public {
        assertEq(adapter.swapper(), address(0));

        vm.expectEmit();
        emit SwapperSet(newSwapper);

        adapter.exposed_setSwapper(newSwapper);

        assertEq(adapter.swapper(), newSwapper);
    }
}
