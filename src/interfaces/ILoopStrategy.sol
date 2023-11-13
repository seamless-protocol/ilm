// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { CollateralRatio } from "../types/DataTypes.sol";

/// @title IStrategy
/// @notice interface for Integration Liquiity Market strategies
/// @dev interface similar to IERC4626, with some additional functions for health management
interface ILoopStrategy is IERC4626 {
    /// @notice mint function from IERC4626 is disabled
    error MintDisabled();
    /// @notice reverts when deposit staticcal from previewDeposit reverts
    error DepositStaticcallReverted();
    /// @notice reverts when rebalance function is called but collateral ratio is in the target range
    error RebalanceNotNeeded();
    /// @notice reverts when shares received by user on deposit is lower than given minimum
    /// @param sharesReceived amount of shares received
    /// @param minSharesReceived minimum defined by caller
    error SharesReceivedBelowMinimum(uint256 sharesReceived, uint256 minSharesReceived);

    /// @notice returns the amount of equity belonging to the strategy
    /// in underlying value (USD)
    /// @return amount equity amount
    function equity() external view returns (uint256 amount);

    /// @notice returns the amount of debt belonging to the strategy
    /// in underlying value (USD)
    /// @return amount debt amount
    function debt() external view returns (uint256 amount);

    /// @notice returns the amount of collateral belonging to the strategy
    /// in underlying value (USD)
    /// @return amount collateral amount
    function collateral() external view returns (uint256 amount);

    /// @notice sets the collateral ratio targets (target ratio, min and max for rebalance, 
    /// @notice max for deposit rebalance and min for collateral rebalance)
    /// @param collateralRatioTargets collateral ratio targets struct
    function setCollateralRatioTargets(CollateralRatio memory collateralRatioTargets) external;

    /// @notice returns min, max and target collateral ratio values
    /// @return ratio struct containing min, max and target collateral ratio values
    function getCollateralRatioTargets() external view returns (CollateralRatio memory ratio);

    /// @notice sets the interest rate mode for the loan
    /// @param interestRateMode interest rate mode per aave enum InterestRateMode {NONE, STABLE, VARIABLE}
    function setInterestRateMode(uint256 interestRateMode) external;

    /// @notice returns the current collateral ratio value of the strategy
    /// @return ratio current collateral ratio value
    function currentCollateralRatio() external view returns (uint256 ratio);

    /// @notice rebalances the strategy
    /// @dev perofrms a downwards/upwards leverage depending on the current strategy state in order to be
    /// within collateral ratio range
    /// @return ratio value of collateral ratio after strategy rebalances
    function rebalance() external returns (uint256 ratio);
    
    /// @notice retruns true if collateral ratio is out of the target range, and we need to rebalance pool
    /// @return shouldRebalance true if rebalance is needed
    function rebalanceNeeded() external view returns(bool shouldRebalance);

    /// @notice deposit assets to the strategy with the requirement of shares received
    /// @param assets amount of assets to deposit
    /// @param receiver address of the receiver of share tokens
    /// @param minSharesReceived required minimum of shares received
    /// @return shares number of received shares
    function deposit(uint256 assets, address receiver, uint256 minSharesReceived) external returns (uint256 shares);
}
