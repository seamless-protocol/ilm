// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { Step } from "../types/DataTypes.sol";

/// @title ISwapper
/// @notice interface for Swapper contract
/// @dev Swapper contract functions as registry and router for Swapper Adapters
interface ISwapper {
    /// @notice thrown when attempting to set a USD value which is outside the USD range
    /// of ONE_USD (1e8)
    error USDValueOutsideRange();

    /// @notice thrown when attempting to set a maximum acceptable slippage for a given
    /// token which exceeds ONE_WAD (1e18)
    error SlippageOutsideRange();

    /// @notice thrown when attempting to set a route which has the zero-address as
    /// the address of the adapter
    error InvalidAddress();

    /// @notice thrown when msg.sender attempting to call executeSwap without being part of the
    /// strategies enumerable set
    error NotStrategy();

    /// @notice thrown when less tokens than the minimum are returned after a swap
    error MaxSlippageExceeded();

    /// @notice emitted when a route is set for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param steps array of Step structs needed to perform swap
    event RouteSet(IERC20 indexed from, IERC20 indexed to, Step[] steps);

    /// @notice emitted when the offsetFactor of a route is set for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param offsetUSD offsetFactor from 0 - 1e8
    event OffsetFactorSet(
        IERC20 indexed from, IERC20 indexed to, uint256 offsetUSD
    );

    /// @notice emitted when the oracle for a given token is set
    /// @param oracle address of PriceOracleGetter contract
    event OracleSet(IPriceOracleGetter oracle);

    /// @notice emitted when a new value for the allowed deviation from the offsetFactor
    /// is set
    event OffsetDeviationSet(uint256 offsetDeviationUSD);

    /// @notice emitted when a route is removed
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    event RouteRemoved(IERC20 indexed from, IERC20 indexed to);

    /// @notice emitted when a strategy is added to strategies enumerable set
    /// @param strategy address of added strategy
    event StrategyAdded(address strategy);

    /// @notice emitted when a strategy is removed from strategies enumerable set
    /// @param strategy address of added strategy
    event StrategyRemoved(address strategy);

    /// @notice returns the steps of a swap route
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @return steps array of swap steps needed to end up with `to` token from `from` token
    function getRoute(IERC20 from, IERC20 to)
        external
        returns (Step[] memory steps);

    /// @notice sets the a steps of a swap route
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param steps  array of swap steps needed to end up with `to` token from `from` token
    function setRoute(IERC20 from, IERC20 to, Step[] calldata steps) external;

    /// @notice deletes an existing route
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function removeRoute(IERC20 from, IERC20 to) external;

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function swap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount);

    /// @notice calculates the offset factor for the entire swap route from `from` token to `to` token
    /// @param from address of `from` token
    /// @param to address of `to` token
    /// @return offsetUSD factor between 0 - 1e8 to represent offset (1e8 is 100% offset so 0 value returned)
    function offsetFactor(IERC20 from, IERC20 to)
        external
        view
        returns (uint256 offsetUSD);

    /// @notice sets the offset factor for the entire swap route from `from` token to `to` token
    /// @param from address of `from` token
    /// @param to address of `to` token
    /// @param offsetUSD factor between 0 - 1e8 to represent offset (1e8 is 100% offset so 0 value returned)
    function setOffsetFactor(IERC20 from, IERC20 to, uint256 offsetUSD)
        external;

    /// @notice sets a new value for the offsetDeviationUSD from the offsetFactor
    /// @param offsetDeviationUSD new value for the offsetDeviationUSD
    function setOffsetDeviationUSD(uint256 offsetDeviationUSD) external;

    /// @notice sets a new address for the oracle
    /// @param oracle new IPriceOracleGetter contract address
    function setOracle(IPriceOracleGetter oracle) external;

    /// @notice returns address of oracle contract
    /// @return oracle address of oracle contract
    function getOracle() external view returns (IPriceOracleGetter oracle);

    /// @notice returns offsetDeviationUSD value
    /// @return offsetDeviationUSD offsetDeviationUSD value
    function getOffsetDeviationUSD()
        external
        view
        returns (uint256 offsetDeviationUSD);
}
