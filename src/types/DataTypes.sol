// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

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
    /// @dev wrapped address of underlying asset of the leverage strategy (asset that users are providing)
    IERC20 underlying;
    /// @dev wrapped adddress of collateralized asset of leverage strategy
    /// @dev this can be different from underlying in cases when we need to wrap
    /// @dev the underlying token to be able to supply it to the lending pool
    IERC20 collateral;
    /// @dev wrapped address of borrowed asset of leverage strategy
    IERC20 debt;
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
    uint256 collateralUSD;
    /// @dev debt value in underlying (USD)
    uint256 debtUSD;
    /// @dev max amount of collateralAsset which can be withdrawn based on maxLTV to
    /// avoid health of loan ratio entering liquidation zone
    uint256 maxWithdrawAmount;
}
