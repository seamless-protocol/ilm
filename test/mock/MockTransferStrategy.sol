
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockTransferStrategy {
    function performTransfer(address to, address reward, uint256 amount)
        external
        returns (bool)
    {
        IERC20(reward).transfer(to, amount);
        return true;
    }
}
