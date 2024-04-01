// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ILMFactoryStorage as Storage } from "../storage/ILMFactoryStorage.sol";
import { IILMFactory } from "../interfaces/IILMFactory.sol";
import { ILMBeaconProxy } from "./ILMBeaconProxy.sol";

contract ILMFactory is
    IILMFactory,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function ILMFactory_init(address _initialAdmin) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    { }

    function setILMImplementation(uint256 ilmId, address ilmImplementation)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (ilmImplementation.code.length == 0) {
            // TODO: revert
        }

        Storage.layout().ilmImplementations[ilmId] = ilmImplementation;
        // TODO: event
    }

    function getILMImplementation(uint256 ilmId)
        external
        view
        returns (address ilmImplementaiton)
    {
        return Storage.layout().ilmImplementations[ilmId];
    }

    function deployNewBeaconProxy(uint256 ilmId, bytes memory data)
        external
        onlyRole(MANAGER_ROLE)
    {
        address newILMBeaconProxy = address(new ILMBeaconProxy(IILMFactory(address(this)), ilmId, data));
        registerNewILM(ilmId, newILMBeaconProxy);
    }

    function registerNewILM(uint256 ilmId, address proxyAddress)
        public
        onlyRole(MANAGER_ROLE)
    {
        _registerNewILM(ilmId, proxyAddress);
    }

    function _registerNewILM(uint256 ilmId, address proxyAddress) internal {
        Storage.layout().ilmProxies[ilmId].push(proxyAddress);
    }

    function getILMs(uint256 ilmId)
        external
        view
        returns (address[] memory ilmProxies)
    {
        return Storage.layout().ilmProxies[ilmId];
    }
}
