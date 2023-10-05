// SPDX-License-Identifier: UNLICENSED

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

pragma solidity ^0.8.18;

/// @title DataTypes
/// @notice Contains all structs used in the Integrated Liquidity Market contract suite

/// @dev contains all data relating to the collateral ratio
struct CollateralRatio {
    /// @dev mininimum value of the collateral ratio
    uint256 min;
    /// @dev maximum value of the collateral ratio
    uint256 max;
    /// @dev target (ideal) value of the collateral ratio
    uint256 target;
}

/// @dev contains all data pertaining to the current position state of the strategy
struct LoanState {
    /// @dev wrapped adddress of collateralized asset of leverage strategy
    IERC20 collateralAsset;
    /// @dev wrapped address of borrowed asset of leverage strategy
    IERC20 borrowedAsset;
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
