// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ISwapper } from "../interfaces/ISwapper.sol";
import { CollateralRatio, LoanState } from "../types/DataTypes.sol";

/// @title RebalanceLogic
/// @notice Contains all logic required for rebalancing 
library RebalanceLogic {
    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param loanState the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt, maxLTV)
    /// @param swapper address of Swapper contract
    /// @return ratio value of collateralRatio after rebalance
    function rebalanceUp(CollateralRatio memory collateralRatio, LoanState memory loanState, ISwapper swapper) external returns (uint256 ratio) {}

    /// @notice performs all operations necessary to rebalance the loan state of the strategy downwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param loanState the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt, maxLTV)
    /// @param swapper address of Swapper contract
    /// @return ratio value of collateralRatio after rebalance
    function rebalanceDown(CollateralRatio memory collateralRatio, LoanState memory loanState, ISwapper swapper) external returns (uint256 ratio) {}
}