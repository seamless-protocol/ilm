// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { SwapAdapterBase } from "./SwapAdapterBase.sol";
import { IAerodromeAdapter } from "../../interfaces/IAerodromeAdapter.sol";
import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { IPoolFactory } from "../../vendor/aerodrome/IPoolFactory.sol";
import { IRouter } from "../../vendor/aerodrome/IRouter.sol";

/// @title AerodromeAdapter
/// @notice Adapter contract for executing swaps on aerodrome
contract AerodromeAdapter is SwapAdapterBase, IAerodromeAdapter {
    mapping(IERC20 from => mapping(IERC20 to => IRouter.Route[] routes)) public
        swapRoutes;
    mapping(IERC20 from => mapping(IERC20 to => bool isStable)) public
        isPoolStable;
    mapping(address pair => address factory) public pairFactory;
    address public router;
    address public poolFactory;

    constructor(
        address _owner,
        address _router,
        address _factory,
        address _swapper
    ) Ownable(_owner) {
        router = _router;
        poolFactory = _factory;
        _setSwapper(_swapper);
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
        isPoolStable[from][to] = status;

        emit IsPoolStableSet(from, to, status);
    }

    /// @inheritdoc IAerodromeAdapter
    function setPoolFactory(address factory) external onlyOwner {
        poolFactory = factory;

        emit PoolFactorySet(factory);
    }

    /// @inheritdoc IAerodromeAdapter
    function setRouter(address _router) external onlyOwner {
        router = _router;

        emit RouterSet(_router);
    }

    /// @inheritdoc IAerodromeAdapter
    function setRoutes(IERC20 from, IERC20 to, IRouter.Route[] memory routes)
        external
        onlyOwner
    {
        if (swapRoutes[from][to].length != 0) {
            _removeRoutes(from, to);
        }

        for (uint256 i; i < routes.length; ++i) {
            swapRoutes[from][to].push(routes[i]);
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

    /// @inheritdoc IAerodromeAdapter
    function getSwapRoutes(IERC20 from, IERC20 to)
        external
        view
        returns (IRouter.Route[] memory routes)
    {
        return swapRoutes[from][to];
    }

    /// @notice deletes existing routes for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function _removeRoutes(IERC20 from, IERC20 to) internal {
        delete swapRoutes[from][to];

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
        from.transferFrom(msg.sender, address(this), fromAmount);

        from.approve(router, fromAmount);

        uint256[] memory toAmounts = IRouter(router).swapExactTokensForTokens(
            fromAmount,
            0,
            swapRoutes[from][to],
            beneficiary,
            block.timestamp
        );

        toAmount = toAmounts[toAmounts.length - 1];
    }
}
