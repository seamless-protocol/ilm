// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { SwapAdapterBase } from "./SwapAdapterBase.sol";
import { IAerodromeAdapter } from "../../interfaces/IAerodromeAdapter.sol";
import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { AerodromeAdapterStorage as Storage } from
    "../../storage/AerodromeAdapterStorage.sol";
import { IPoolFactory } from "../../vendor/aerodrome/IPoolFactory.sol";
import { IRouter } from "../../vendor/aerodrome/IRouter.sol";

/// @title AerodromeAdapter
/// @notice Adapter contract for executing swaps on aerodrome
contract AerodromeAdapter is SwapAdapterBase, IAerodromeAdapter {
    /// @inheritdoc IAerodromeAdapter
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
    ) external onlySwapper returns (uint256 toAmount) {
        return _executeSwap(from, to, fromAmount, beneficiary);
    }

    /// @inheritdoc IAerodromeAdapter
    function setIsPoolStable(IERC20 from, IERC20 to, bool status)
        external
        onlyOwner
    {
        Storage.layout().isPoolStable[from][to] = status;

        emit IsPoolStableSet(from, to, status);
    }

    /// @inheritdoc IAerodromeAdapter
    function setPoolFactory(address factory) external onlyOwner {
        Storage.layout().poolFactory = factory;

        emit PoolFactorySet(factory);
    }

    /// @inheritdoc IAerodromeAdapter
    function setRouter(address router) external onlyOwner {
        Storage.layout().router = router;

        emit RouterSet(router);
    }

    /// @inheritdoc IAerodromeAdapter
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

    /// @inheritdoc IAerodromeAdapter
    function removeRoutes(IERC20 from, IERC20 to) external onlyOwner {
        _removeRoutes(from, to);
    }

    /// @inheritdoc ISwapAdapter
    function setSwapper(address swapper) external onlyOwner {
        _setSwapper(swapper);
    }

    /// @inheritdoc ISwapAdapter
    function getSwapper() external view returns (address swapper) {
        return _getSwapper();
    }

    /// @inheritdoc IAerodromeAdapter
    function getIsPoolStable(IERC20 from, IERC20 to)
        external
        view
        returns (bool status)
    {
        return Storage.layout().isPoolStable[from][to];
    }

    /// @inheritdoc IAerodromeAdapter
    function getPoolFactory() external view returns (address factory) {
        return Storage.layout().poolFactory;
    }

    //// @inheritdoc IAerodromeAdapter
    function getRouter() external view returns (address router) {
        return Storage.layout().router;
    }

    //// @inheritdoc IAerodromeAdapter
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

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @dev overridden internal _executeSwap function from SwapAdapterBase contract
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function _executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) internal override returns (uint256 toAmount) {
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
}
