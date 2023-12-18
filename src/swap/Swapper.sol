// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISwapper } from "../interfaces/ISwapper.sol";
import { USDWadRayMath } from "../libraries/math/USDWadRayMath.sol";
import { SwapperStorage as Storage } from "../storage/SwapperStorage.sol";
import { Step } from "../types/DataTypes.sol";

/// @title Swapper
/// @notice Routing contract for swaps across different DEXs
contract Swapper is Ownable2StepUpgradeable, ISwapper {
    using EnumerableSet for EnumerableSet.AddressSet;

    modifier onlyStrategy() {
        if(!Storage.layout().strategies.contains(msg.sender)) {
            revert NotStrategy();
        }
        _;
    }

    /// @dev initializer function for Swapper contract
    function Swapper_init(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
    }

    /// @inheritdoc ISwapper
    function getRoute(IERC20 from, IERC20 to)
        external
        view
        returns (Step[] memory steps)
    {
        return Storage.layout().route[from][to];
    }

    /// @inheritdoc ISwapper
    function setRoute(IERC20 from, IERC20 to, Step[] calldata steps)
        external
        onlyOwner
    {
        Storage.Layout storage $ = Storage.layout();

        // remove route if it exists
        if ($.route[from][to].length != 0) {
            _removeRoute(from, to);
        }

        for (uint256 i; i < steps.length; ++i) {
            if (address(steps[i].adapter) == address(0)) {
                revert InvalidAddress();
            }

            $.route[from][to].push(steps[i]);
        }

        emit RouteSet(from, to, steps);
    }

    /// @inheritdoc ISwapper
    function removeRoute(IERC20 from, IERC20 to) external onlyOwner {
        _removeRoute(from, to);
    }

    /// @inheritdoc ISwapper
    function offsetFactor(IERC20 from, IERC20 to)
        external
        view
        returns (uint256 offsetUSD)
    {
        return Storage.layout().offsetUSD[from][to];
    }

    /// @inheritdoc ISwapper
    function setOffsetFactor(IERC20 from, IERC20 to, uint256 offsetUSD)
        external
        onlyOwner
    {
        if (offsetUSD == 0 || offsetUSD > USDWadRayMath.USD) {
            revert OffsetOutsideRange();
        }

        Storage.layout().offsetUSD[from][to] = offsetUSD;

        emit OffsetFactorSet(from, to, offsetUSD);
    }

    /// @inheritdoc ISwapper
    function swap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external onlyStrategy returns (uint256 toAmount) {
        Step[] memory steps = Storage.layout().route[from][to];

        from.transferFrom(msg.sender, address(this), fromAmount);

        // execute the swap for each swap-step in the route,
        // updating `fromAmount` to be the amount received from
        // each step
        for (uint256 i; i < steps.length; ++i) {
            steps[i].from.approve(address(steps[i].adapter), fromAmount);

            // should handle address(0) cases ie for ETH?
            fromAmount = steps[i].adapter.executeSwap(
                steps[i].from, steps[i].to, fromAmount, payable(address(this))
            );
        }

        // set the received amount as the amount received from the final
        // step of the route
        toAmount = fromAmount;

        to.transfer(beneficiary, toAmount);
    }

    /// @notice deletes an existing route
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function _removeRoute(IERC20 from, IERC20 to) internal {
        delete Storage.layout().route[from][to];

        emit RouteRemoved(from, to);
    }
}
