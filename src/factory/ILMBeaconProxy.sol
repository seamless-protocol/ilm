// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ERC1967Utils } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IILMFactory } from "../interfaces/IILMFactory.sol";

contract ILMBeaconProxy is Proxy {
    IILMFactory private immutable _ilmFactory;
    uint256 private immutable _ilmId;

    constructor(IILMFactory ilmFactory, uint256 ilmId, bytes memory data)
        payable
    {
        if (data.length > 0) {
            Address.functionDelegateCall(
                ilmFactory.getILMImplementation(ilmId), data
            );
        } else {
            _checkNonPayable();
        }

        _ilmFactory = ilmFactory;
        _ilmId = ilmId;
    }

    function _implementation()
        internal
        view
        virtual
        override
        returns (address)
    {
        return _ilmFactory.getILMImplementation(_ilmId);
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            // TODO: revert NotPayable();
        }
    }
}
