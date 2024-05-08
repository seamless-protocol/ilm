// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { ILMRegistry } from "../../../src/ILMRegistry.sol";
import { BaseMainnetConstants } from "../config/BaseMainnetConstants.sol";

contract DeployILMRegistry is Script, BaseMainnetConstants {
    address internal constant WSTETHETHLOOP =
        0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e;
    address internal constant ETHUSDCLOOP = 0x2FB1bEa0a63F77eFa77619B903B2830b52eE78f4;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        ILMRegistry registry = new ILMRegistry(deployer);

        registry.addILM(WSTETHETHLOOP);
        registry.addILM(ETHUSDCLOOP);

        registry.grantRole(
            registry.DEFAULT_ADMIN_ROLE(), SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS
        );
        registry.grantRole(
            registry.DEFAULT_ADMIN_ROLE(), SEAMLESS_COMMUNITY_MULTISIG
        );

        registry.grantRole(
            registry.MANAGER_ROLE(), SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS
        );
        registry.grantRole(registry.MANAGER_ROLE(), SEAMLESS_COMMUNITY_MULTISIG);

        assert(
            registry.hasRole(
                registry.DEFAULT_ADMIN_ROLE(),
                SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS
            )
        );
        assert(
            registry.hasRole(
                registry.MANAGER_ROLE(),
                SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS
            )
        );

        assert(
            registry.hasRole(
                registry.DEFAULT_ADMIN_ROLE(),
                SEAMLESS_COMMUNITY_MULTISIG
            )
        );
         assert(
            registry.hasRole(
                registry.MANAGER_ROLE(),
                SEAMLESS_COMMUNITY_MULTISIG
            )
        );

        registry.revokeRole(registry.MANAGER_ROLE(), deployer);
        registry.revokeRole(registry.DEFAULT_ADMIN_ROLE(), deployer);
        vm.stopBroadcast();

        assert(
            !registry.hasRole(
                registry.DEFAULT_ADMIN_ROLE(),
               deployer
            )
        );
         assert(
            !registry.hasRole(
                registry.MANAGER_ROLE(),
                deployer
            )
        );

        console.log("ILM Registry deployed at: ", address(registry));
    }
}
