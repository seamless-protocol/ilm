// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { LoanLogic } from "./LoanLogic.sol";
import { USDWadMath } from "./math/USDWadMath.sol";
import { IPriceOracleGetter } from "../interfaces/IPriceOracleGetter.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
import { StrategyAssets, LoanState } from "../types/DataTypes.sol";
import { IPriceOracleGetter } from "../interfaces/IPriceOracleGetter.sol";

/// @title RebalanceLogic
/// @notice Contains all logic required for rebalancing
library RebalanceLogic {
    using USDWadMath for uint256;

    /// @dev ONE in USD scale and in TOKEN scale
    uint256 internal constant ONE_USD = 1e8;
    uint256 internal constant ONE_TOKEN = USDWadMath.WAD;

    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param loanState the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt, maxLTV)
    /// @param oracle aave oracle
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
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param loanState the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt, maxLTV)
    /// @param oracle aave oracle
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
