// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { DeployHelper } from "./DeployHelper.s.sol";

contract DeploySwapperImplementation is Script, DeployHelper {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(deployerPrivateKey);

        _deploySwapperImplementation();

        vm.stopBroadcast();
    }
}
