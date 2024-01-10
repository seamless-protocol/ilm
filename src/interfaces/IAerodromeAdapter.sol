// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRouter } from "../vendor/aerodrome/IRouter.sol";

/// @title IAerodromeAdapter
/// @notice interface for AerodromeAdapter functionality
interface IAerodromeAdapter {
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
    ) external;

    /// @notice sets the `isPoolStable` boolean for a given pair
    /// @param from address of first token
    /// @param to address of second token
    /// @param status value to set `isPoolStable` to
    function setIsPoolStable(IERC20 from, IERC20 to, bool status) external;

    /// @notice sets the poolFactory address
    /// @param factory poolFactory address
    function setPoolFactory(address factory) external;

    /// @notice sets the router address
    /// @param router router address
    function setRouter(address router) external;

    /// @notice sets routes for a given swap
    /// @param from address of token to swap from
    /// @param to address of tokent to swap to
    /// @param routes routes for the swap
    function setRoutes(IERC20 from, IERC20 to, IRouter.Route[] memory routes)
        external;

    /// @notice deletes existing routes for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function removeRoutes(IERC20 from, IERC20 to) external;

    /// @notice fetches the 'stable' status of a pool
    /// @param from address of `from` token
    /// @param to address of `to` token
    /// @return status 'stable' status of pool
    function getIsPoolStable(IERC20 from, IERC20 to)
        external
        view
        returns (bool status);

    /// @notice fetches the Aerodrome PoolFactory address
    /// @return factory address of Aerodrome PoolFactory contract
    function getPoolFactory() external view returns (address factory);

    /// @notice fetches the Aerodrome Router address
    /// @return router address of Aerodrome Router contract
    function getRouter() external view returns (address router);

    /// @notice fetches the swap routes for a given token swap
    /// @param from address of `from` token
    /// @param to address of `to` token
    /// @return routes IRouter.Route struct array corresponding to the token swap
    function getSwapRoutes(IERC20 from, IERC20 to)
        external
        view
        returns (IRouter.Route[] memory routes);
}
