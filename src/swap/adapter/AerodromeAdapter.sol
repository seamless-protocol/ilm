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
    
    /// @notice emitted when a value whether a pool is stable or not is set
    /// @param from first token of the pool
    /// @param to second token of the pool
    /// @param status boolean value indicating pool stability
    event IsPoolStableSet(IERC20 from, IERC20 to, bool status);

    /// @notice emitted when the poolFactory address is set
    /// @param factory address of poolFactory
    event PoolFactorySet(address factory);

    /// @notice emitted when the router address is set
    /// @param router address of router
    event RouterSet(address router);

    /// @notice emitted when the swap routes for a token pair are set
    /// @param from first token of the pool
    /// @param to second token of the pool
    /// @param routes array of routes for swap
    event RoutesSet(IERC20 from, IERC20 to, IRouter.Route[] routes);

    
    function AerodromeAdapter__Init(address owner, address router, address factory)  external initializer {
        __Ownable_init(owner);

        Storage.Layout storage $ =  Storage.layout();
        $.router = router;
        $.poolFactory = factory;
    }

    /// @inheritdoc ISwapAdapter
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount) {
        Storage.Layout storage $ = Storage.layout();

        from.transferFrom(msg.sender, address(this), fromAmount);

        from.approve($.router, fromAmount);

        console.log($.swapRoutes[from][to].length);

        uint256[] memory toAmounts = IRouter($.router).swapExactTokensForTokens(
            fromAmount, 0, $.swapRoutes[from][to], beneficiary, block.timestamp + 10
        );

        toAmount = toAmounts[toAmounts.length - 1];
    }

    /// @notice sets the `isPoolStable` boolean for a given pair
    /// @param from address of first token
    /// @param to address of second token
    /// @param status value to set `isPoolStable` to
    function setIsPoolStable(IERC20 from, IERC20 to, bool status)
        external
        onlyOwner
    { 
        Storage.layout().isPoolStable[from][to] = status;

        emit IsPoolStableSet(from, to, status);
    }

    /// @notice sets the poolFactory address
    /// @param factory poolFactory address
    function setPoolFactory(address factory) external onlyOwner {
        Storage.layout().poolFactory = factory;

        emit PoolFactorySet(factory);
    }

    /// @notice sets the router address
    /// @param router router address
    function setRouter(address router) external onlyOwner {
        Storage.layout().router = router;

        emit RouterSet(router);
    }

    function setRoutes(IERC20 from, IERC20 to, IRouter.Route[] memory routes) external onlyOwner {
        Storage.Layout storage $ = Storage.layout();

        if ($.swapRoutes[from][to].length != 0) {
            delete $.swapRoutes[from][to];
        }

        for(uint256 i; i < routes.length; ++i) {
            $.swapRoutes[from][to].push(routes[i]);
        }

        emit RoutesSet(from, to, routes);
    }
}
