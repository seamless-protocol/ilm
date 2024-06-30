// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import { MockERC20 } from "./MockERC20.sol";

contract MockTransferStrategy {
    function performTransfer(address to, address reward, uint256 amount)
        external
        returns (bool)
    {
        MockERC20(reward).mint(to, amount);
        return true;
    }
}
