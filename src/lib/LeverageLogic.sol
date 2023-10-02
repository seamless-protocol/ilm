// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ISwapper } from "../interfaces/ISwapper.sol";
import { CollateralRatio, Position } from "../types/DataTypes.sol";

/// @title LeverageLogic
/// @notice Contains all logic required for leveraging 
library LeverageLogic {
    /// @notice performs all operations necessary to leverage the position of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param position the strategy position information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param swapper address of Swapper contract
    function leverageUp(CollateralRatio memory collateralRatio, Position memory position, ISwapper swapper) external {}

    /// @notice performs all operations necessary to leverage the position of the strategy downwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param position the strategy position information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param swapper address of Swapper contract
    function leverageDown(CollateralRatio memory collateralRatio, Position memory position, ISwapper swapper) external {}
}