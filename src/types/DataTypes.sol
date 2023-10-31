// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";

/// @title DataTypes
/// @notice Contains all structs used in the Integrated Liquidity Market contract suite

/// @dev contains all data relating to the collateral ratio
struct CollateralRatio {
    /// @dev target (ideal) value of the collateral ratio
    uint256 target;
    /// @dev mininimum value of the collateral ratio below which strategy will rebalance
    uint256 minForRebalance;
    /// @dev maximum value of the collateral ratio above which strategy will rebalance
    uint256 maxForRebalance;
    /// @dev minimum value of the collateral ratio, above which rebalance for withdrawing action is not needed
    uint256 minForWithdrawRebalance;
    /// @dev maximum value of the collateral ratio, below which rebalance for depositing action is not needed
    uint256 maxForDepositRebalance;
}

/// @dev contains assets addresses that strategy is using
struct StrategyAssets {
    /// @dev wrapped adddress of collateralized asset of leverage strategy
    IERC20 collateralAsset;
    /// @dev wrapped address of borrowed asset of leverage strategy
    IERC20 borrowedAsset;
}

/// @dev conatins address of the lending pool and configuration
struct LendingPool {
    /// @dev address of the lending pool
    IPool pool;
    /// @dev interest rate mode used on loan
    uint256 interestRateMode;
}

/// @dev contains all data pertaining to the current position state of the strategy
struct LoanState {
    /// @dev collateral value in underlying (USD)
    uint256 collateral;
    /// @dev debt value in underlying (USD)
    uint256 debt;
    /// @dev max amount of borrowedAsset borrowable based on maxLTV
    uint256 maxBorrowAmount;
    /// @dev max amount of collateralAsset which can be withdrawn based on maxLTV to
    /// avoid health of loan ratio entering liquidation zone
    uint256 maxWithdrawAmount;
}