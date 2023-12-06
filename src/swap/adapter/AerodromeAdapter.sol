// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { AerodromeAdapterStorage as Storage } from
    "../../storage/AerodromeAdapterStorage.sol";
import { IPoolFactory } from "../../vendor/aerodrome/IPoolFactory.sol";
import { IRouter } from "../../vendor/aerodrome/IRouter.sol";

/// @title AerodromeAdapter
/// @notice Adapter contract for executing swaps on aerodrome
contract AerodromeAdapter is Ownable2StepUpgradeable, ISwapAdapter {
    function AerodromeAdapter__Init(address router) external initializer {
        Storage.layout().router = router;
    }

    /// @inheritdoc ISwapAdapter
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount) {
        Storage.Layout storage $ = Storage.layout();

        toAmount = IRouter($.router).swapExactTokensForTokens(
            address(from), address(to), fromAmount, $.isPoolStable[from][to]
        );

        to.transfer(toAmount, beneficiary);
    }

    function setIsPoolStable(IERC20 from, IERC20 to, bool status)
        external
        onlyOwner
    { }
}
