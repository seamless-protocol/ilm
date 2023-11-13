// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPriceOracleGetter } from "../interfaces/IPriceOracleGetter.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
import { LoanState, StrategyAssets } from "../types/DataTypes.sol";

/// @title RebalanceLogic
/// @notice Contains all logic required for rebalancing
library RebalanceLogic {
    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param strategyAssets strategy assets (collateralized asset, borrowed asset)
    /// @param loanState the strategy loan state information (current collateral, current debt, max borrow available, max withdraw available)
    /// @param targetRatio ratio to which we want to achive with rebalance
    /// @param oracle aave oracl
    /// @param swapper address of Swapper contract
    /// @return ratio value of collateralRatio after rebalance
    function rebalanceUp(
        StrategyAssets memory strategyAssets,
        LoanState memory loanState,
        uint256 targetRatio,
        IPriceOracleGetter oracle,
        ISwapper swapper
    ) external returns (uint256 ratio) { }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy downwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param strategyAssets strategy assets (collateralized asset, borrowed asset)
    /// @param loanState the strategy loan state information (current collateral, current debt, max borrow available, max withdraw available)
    /// @param targetRatio ratio to which we want to achive with rebalance
    /// @param oracle aave oracl
    /// @param swapper address of Swapper contract
    /// @return ratio value of collateralRatio after rebalance
    function rebalanceDown(
        StrategyAssets memory strategyAssets,
        LoanState memory loanState,
        uint256 targetRatio,
        IPriceOracleGetter oracle,
        ISwapper swapper
    ) external returns (uint256 ratio) { }
}
