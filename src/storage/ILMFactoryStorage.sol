// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

library ILMFactoryStorage {
    /// @custom:storage-location erc7201:seamless.contracts.storage.ILMFactory
    struct Layout {
        mapping(uint256 ilmId => address ilmImplementation) ilmImplementations;
        mapping(uint256 ilmId => address[] ilmProxy) ilmProxies;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.ILMFactory")) - 1)) & ~bytes32(uint256(0xff));
    // TODO: add slot
    bytes32 internal constant STORAGE_SLOT = 0x0;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
