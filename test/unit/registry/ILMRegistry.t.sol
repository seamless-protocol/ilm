// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { ILMRegistry } from "../../../src/ILMRegistry.sol";

contract ILMRegistryTest is Test {
    /// @notice emitted when a new ILM proxy contract address is added to
    /// the ilmSet
    /// @param ilm address of ILM proxy contract
    event ILMAdded(address ilm);

    /// @notice emitted when an ILM proxy contract address is remove from
    /// the ilmSet
    /// @param ilm address of ILM proxy contract
    event ILMRemoved(address ilm);

    ILMRegistry registry;

    address ADMIN = makeAddr("admin");
    address NON_PERMISSIONED = makeAddr("non-permissioned");
    address ILM_PROXY = makeAddr("ilm-proxy");

    function setUp() public {
        registry = new ILMRegistry(ADMIN);
    }

    function test_setUp() public {
        assertNotEq(address(registry), address(0));
    }

    function test_addILM_addsILMtoILMSet() public {
        vm.startPrank(ADMIN);
        registry.addILM(ILM_PROXY);
        vm.stopPrank();

        assertEq(registry.countILM(), 1);
        assertEq(ILM_PROXY, registry.getILM(0));

        address[] memory ilms = registry.getAllILMs();
        assertEq(ilms.length, 1);
        assertEq(ilms[0], ILM_PROXY);
    }

    function test_addILM_emitsILMAdded_event() public {
        vm.expectEmit();
        emit ILMAdded(ILM_PROXY);

        vm.startPrank(ADMIN);
        registry.addILM(ILM_PROXY);
        vm.stopPrank();
    }

    function test_removeILM_removesILMProxyAddress_fromILMSet() public {
        vm.startPrank(ADMIN);
        registry.addILM(ILM_PROXY);
        vm.stopPrank();

        assertEq(registry.countILM(), 1);
        assertEq(ILM_PROXY, registry.getILM(0));

        vm.startPrank(ADMIN);
        registry.removeILM(ILM_PROXY);
        vm.stopPrank();

        assertEq(registry.countILM(), 0);
    }

    function test_removeILM_emitsILMRemoved_event() public {
        vm.startPrank(ADMIN);
        registry.addILM(ILM_PROXY);
        vm.stopPrank();

        assertEq(registry.countILM(), 1);
        assertEq(ILM_PROXY, registry.getILM(0));

        vm.expectEmit();
        emit ILMRemoved(ILM_PROXY);

        vm.startPrank(ADMIN);
        registry.removeILM(ILM_PROXY);
        vm.stopPrank();
    }
}
