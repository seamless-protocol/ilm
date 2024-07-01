// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MockTransferStrategy {
    function performTransfer(address to, address reward, uint256 amount)
        external
        returns (bool)
    {
        ERC20Mock(reward).mint(to, amount);
        return true;
    }
}
