// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { Console } from "forge-std/Console.sol";

import { ILMRegistry } from "../../../src/ILMRegistry.sol";

contract DeployILMRegistry is Script {
    // replace for deployment
    address public INITIAL_ADMIN = address(0);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        ILMRegistry registry = new ILMRegistry(INITIAL_ADMIN);
        vm.stopBroadcast();

        console.log("ILM Registry deployed at: ", address(registry));
    }
}
