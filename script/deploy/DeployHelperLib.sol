// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRouter } from "../../src/vendor/aerodrome/IRouter.sol";
import { IAerodromeAdapter } from "../../src/interfaces/IAerodromeAdapter.sol";
import { IWrappedERC20PermissionedDeposit } from
    "../../src/interfaces/IWrappedERC20PermissionedDeposit.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";
import { Step, StrategyAssets } from "../../src/types/DataTypes.sol";
import { LoopStrategyConfig } from "./config/LoopStrategyConfig.sol";

/// @title DeployHelperLib
/// @notice Library contains functions to help with deploy and setup ILM contracts
library DeployHelperLib {
    /// @dev sets simple routes on AerodromeAdapter between tokenA <-> tokenB pair
    /// @dev requires for the caller to be the owner of AerodromeAdapter
    /// @param aerodromeAdapter address of the AerodromeAdapter
    /// @param tokenA tokenA
    /// @param tokenB tokenB
    /// @param aerodromeFactory address of the Aerodrom Factory contract
    function _setAerodromeAdapterRoutes(
        IAerodromeAdapter aerodromeAdapter,
        IERC20 tokenA,
        IERC20 tokenB,
        address aerodromeFactory
    ) internal {
        IRouter.Route[] memory routesAtoB= new IRouter.Route[](1);
        routesAtoB[0] = IRouter.Route({
            from: address(tokenA),
            to: address(tokenB),
            stable: false,
            factory: aerodromeFactory
        });

        IRouter.Route[] memory routesBtoA = new IRouter.Route[](1);
        routesBtoA[0] = IRouter.Route({
            from: address(tokenB),
            to: address(tokenA),
            stable: false,
            factory: aerodromeFactory
        });

        aerodromeAdapter.setRoutes(tokenA, tokenB, routesAtoB);
        aerodromeAdapter.setRoutes(tokenB, tokenA, routesBtoA);
    }

    /// @dev set up the routes for swapping (wrappedTokenA <-> tokenB)
    /// @dev requires for the caller to have MANAGER_ROLE on the Swapper contract
    /// @param swapper address of the Swapper contract
    /// @param wrappedTokenA address of the WrappedToken contract
    /// @param tokenB address of the tokenB
    /// @param wrappedTokenAdapter address of the WrappedTokenAdapter contract
    /// @param aerodromeAdapter address of the AerodromeAdapter contract
    /// @param swapperOffsetFactor offsetFactor for this swapping routes
    function _setSwapperRouteBetweenWrappedAndToken(
        ISwapper swapper,
        IWrappedERC20PermissionedDeposit wrappedTokenA,
        IERC20 tokenB,
        ISwapAdapter wrappedTokenAdapter,
        ISwapAdapter aerodromeAdapter,
        uint256 swapperOffsetFactor
    ) internal {
        IERC20 underlyingTokenA = wrappedTokenA.underlying();

        // from wrappedTokenA -> tokenB
        Step[] memory stepsAtoB = new Step[](2);
        stepsAtoB[0] = Step({
            from: IERC20(address(wrappedTokenA)),
            to: underlyingTokenA,
            adapter: wrappedTokenAdapter
        });
        stepsAtoB[1] = Step({
            from: underlyingTokenA,
            to: tokenB,
            adapter: aerodromeAdapter
        });

        // from tokenB -> wrappedTokenA
        Step[] memory stepsBtoA = new Step[](2);
        stepsBtoA[0] = Step({
            from: tokenB,
            to: underlyingTokenA,
            adapter: aerodromeAdapter
        });
        stepsBtoA[1] = Step({
            from: underlyingTokenA,
            to: IERC20(address(wrappedTokenA)),
            adapter: wrappedTokenAdapter
        });

        swapper.setRoute(
            IERC20(address(wrappedTokenA)), tokenB, stepsAtoB
        );
        swapper.setOffsetFactor(
            IERC20(address(wrappedTokenA)), tokenB, swapperOffsetFactor
        );

        swapper.setRoute(
            tokenB, IERC20(address(wrappedTokenA)), stepsBtoA
        );
        swapper.setOffsetFactor(
            tokenB, IERC20(address(wrappedTokenA)), swapperOffsetFactor
        );
    }
}
