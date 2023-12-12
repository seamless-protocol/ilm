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

    /// @notice emitted when set routes for a given swap are removed
    /// @param from address to swap from
    /// @param to addrses to swap to
    event RoutesRemoved(IERC20 from, IERC20 to);

    /// @notice emitted when the swap routes for a token pair are set
    /// @param from first token of the pool
    /// @param to second token of the pool
    /// @param routes array of routes for swap
    event RoutesSet(IERC20 from, IERC20 to, IRouter.Route[] routes);

    /// @notice initializing function of adapter
    /// @param owner address of adapter owner
    /// @param router address of Aerodrome router
    /// @param factory address of Aerodrome pair factory
    function AerodromeAdapter__Init(
        address owner,
        address router,
        address factory
    ) external initializer {
        __Ownable_init(owner);

        Storage.Layout storage $ = Storage.layout();
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

        uint256[] memory toAmounts = IRouter($.router).swapExactTokensForTokens(
            fromAmount,
            0,
            $.swapRoutes[from][to],
            beneficiary,
            block.timestamp + 10
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

    /// @notice sets routes for a given swap
    /// @param from address of token to swap from
    /// @param to address of tokent to swap to
    /// @param routes routes for the swap
    function setRoutes(IERC20 from, IERC20 to, IRouter.Route[] memory routes)
        external
        onlyOwner
    {
        Storage.Layout storage $ = Storage.layout();

        if ($.swapRoutes[from][to].length != 0) {
            _removeRoutes(from, to);
        }

        for (uint256 i; i < routes.length; ++i) {
            $.swapRoutes[from][to].push(routes[i]);
        }

        emit RoutesSet(from, to, routes);
    }

    /// @notice deletes existing routes for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function removeRoutes(IERC20 from, IERC20 to) external onlyOwner {
        _removeRoutes(from, to);
    }

    /// @notice fetches the 'stable' status of a pool
    /// @param from address of `from` token
    /// @param to address of `to` token
    /// @return status 'stable' status of pool
    function getIsPoolStable(IERC20 from, IERC20 to)
        external
        view
        returns (bool status)
    {
        return Storage.layout().isPoolStable[from][to];
    }

    /// @notice fetches the Aerodrome PoolFactory address
    /// @return factory address of Aerodrome PoolFactory contract
    function getPoolFactory() external view returns (address factory) {
        return Storage.layout().poolFactory;
    }

    /// @notice fetches the Aerodrome Router address
    /// @return router address of Aerodrome Router contract
    function getRouter() external view returns (address router) {
        return Storage.layout().router;
    }

    /// @notice fetches the swap routes for a given token swap
    /// @param from address of `from` token
    /// @param to address of `to` token
    /// @return routes IRouter.Route struct array corresponding to the token swap
    function getSwapRoutes(IERC20 from, IERC20 to)
        external
        view
        returns (IRouter.Route[] memory routes)
    {
        return Storage.layout().swapRoutes[from][to];
    }

    /// @notice deletes existing routes for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function _removeRoutes(IERC20 from, IERC20 to) internal {
        delete Storage.layout().swapRoutes[from][to];

        emit RoutesRemoved(from, to);
    }
}
