// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/// @title IStrategy
/// @notice interface for Integration Liquiity Market strategies
/// @dev interface similar to IERC4626, with some additional functions for health management
interface IStrategy is IERC4626, IPausable, IOwnable, IUUPSUpgradeable {
    /// @notice returns the amount of equity belonging to the strategy
    /// @return amount equity amount
    function equity() external returns (uint256 amount);

    /// @notice sets the minimum and maximum leverage values
    /// @param minLeverage minimum leverage value
    /// @param maxLeverage maximum leverage value
    function setLeverageRange(uint256 minLeverage, uint256 maxLeverage) external;
    
    /// @notice returns the tarvet leverage value of the strategy
    /// @return leverage target leverage value
    function targetLeverage() external returns (uint256 leverage);

    /// @notice returns the current leverage value of the strategy
    /// @return leverage current leverage value
    function currentLeverage() external returns (uint256 leverage);

    /// @notice rebalances the strategy
    /// @dev perofrms a downwards/upwards leverage depending on the current strategy state
    /// @return leverage value of leverage after strategy rebalances
    function rebalance() external returns (uint256 leverage);

}