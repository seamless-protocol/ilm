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
        IRouter.Route[] memory routesUnderlyingtoWETH = new IRouter.Route[](1);
        routesUnderlyingtoWETH[0] = IRouter.Route({
            from: address(tokenA),
            to: address(tokenB),
            stable: false,
            factory: aerodromeFactory
        });

        IRouter.Route[] memory routesWETHtoUnderlying = new IRouter.Route[](1);
        routesWETHtoUnderlying[0] = IRouter.Route({
            from: address(tokenB),
            to: address(tokenA),
            stable: false,
            factory: aerodromeFactory
        });

        aerodromeAdapter.setRoutes(tokenA, tokenB, routesUnderlyingtoWETH);
        aerodromeAdapter.setRoutes(tokenB, tokenA, routesWETHtoUnderlying);
    }

    /// @dev set up the routes for swapping (wrappedToken <-> toToken)
    /// @dev requires for the caller to have MANAGER_ROLE on the Swapper contract
    /// @param swapper address of the Swapper contract
    /// @param wrappedToken address of the WrappedToken contract
    /// @param wrappedTokenAdapter address of the WrappedTokenAdapter contract
    /// @param aerodromeAdapter address of the AerodromeAdapter contract
    /// @param swapperOffsetFactor offsetFactor for this swapping routes
    function _setSwapperRouteBetweenWrappedAndToken(
        ISwapper swapper,
        IWrappedERC20PermissionedDeposit wrappedToken,
        IERC20 toToken,
        ISwapAdapter wrappedTokenAdapter,
        ISwapAdapter aerodromeAdapter,
        uint256 swapperOffsetFactor
    ) internal {
        IERC20 underlyingToken = wrappedToken.underlying();

        // from wrappedToken -> toToken
        Step[] memory stepsWrappedToWETH = new Step[](2);
        stepsWrappedToWETH[0] = Step({
            from: IERC20(address(wrappedToken)),
            to: underlyingToken,
            adapter: wrappedTokenAdapter
        });
        stepsWrappedToWETH[1] = Step({
            from: underlyingToken,
            to: toToken,
            adapter: aerodromeAdapter
        });

        // from toToken -> wrappedToken
        Step[] memory stepsWETHtoWrapped = new Step[](2);
        stepsWETHtoWrapped[0] = Step({
            from: toToken,
            to: underlyingToken,
            adapter: aerodromeAdapter
        });
        stepsWETHtoWrapped[1] = Step({
            from: underlyingToken,
            to: IERC20(address(wrappedToken)),
            adapter: wrappedTokenAdapter
        });

        swapper.setRoute(
            IERC20(address(wrappedToken)), toToken, stepsWrappedToWETH
        );
        swapper.setOffsetFactor(
            IERC20(address(wrappedToken)), toToken, swapperOffsetFactor
        );

        swapper.setRoute(
            toToken, IERC20(address(wrappedToken)), stepsWETHtoWrapped
        );
        swapper.setOffsetFactor(
            toToken, IERC20(address(wrappedToken)), swapperOffsetFactor
        );
    }
}
