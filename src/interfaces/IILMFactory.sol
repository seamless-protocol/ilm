// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

interface IILMFactory {
    function getILMImplementation(uint256 ilmId)
        external
        view
        returns (address ilmImplementaiton);

    function deployNewBeaconProxy(uint256 ilmId, bytes memory data) external;
}
