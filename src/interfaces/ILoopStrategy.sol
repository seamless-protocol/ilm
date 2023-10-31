// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// import { IOwnable2Step } from "./IOwnable2Step.sol";
// import { IPausable } from "./IPausable.sol";

import { CollateralRatio } from "../types/DataTypes.sol";

///TODO: add auxiliary functions

/// @title IStrategy
/// @notice interface for Integration Liquiity Market strategies
/// @dev interface similar to IERC4626, with some additional functions for health management
interface ILoopStrategy is IERC4626 {
    /// @notice returns the amount of equity belonging to the strategy
    /// in underlying value (USD)
    /// @return amount equity amount
    function equity() external returns (uint256 amount);

    /// @notice returns the amount of debt belonging to the strategy
    /// in underlying value (USD)
    /// @return amount debt amount
    function debt() external returns (uint256 amount);

    /// @notice returns the amount of collateral belonging to the strategy
    /// in underlying value (USD)
    /// @return amount collateral amount
    function collateral() external returns (uint256 amount);

    // TODO: fix
    // / @notice sets the minimum and maximum collateral ratio values
    // / @param minRatio minimum collateral ratio value
    // / @param maxRatio maximum collateral ratio value
    function setCollateralRatioConfig(CollateralRatio memory _collateralRatio) external;

    /// @notice returns min, max and target collateral ratio values
    /// @return ratio struct containing min, max and target collateral ratio values
    function getCollateralRatioConfig() external view returns (CollateralRatio memory ratio);

    function setInterestRateMode(uint256 interestRateMode) external;

    /// @notice returns the current collateral ratio value of the strategy
    /// @return ratio current collateral ratio value
    function currentCollateralRatio() external returns (uint256 ratio);

    /// @notice rebalances the strategy
    /// @dev perofrms a downwards/upwards leverage depending on the current strategy state in order to be
    /// within collateral ratio range
    /// @return ratio value of collateral ratio after strategy rebalances
    function rebalance() external returns (uint256 ratio);
    

}
