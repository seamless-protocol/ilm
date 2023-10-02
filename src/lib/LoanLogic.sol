// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Position } from "../types/DataTypes.sol";

/// @title LoanLogic
/// @notice Contains all logic required for managing the loan position 
library LoanLogic {
    /// @dev collateralizes an amount of underlying asset in AaveV3
    /// @param position the strategy position information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param amount amount of collateralization asset to collateralize
    function collateralize(Position memory position, uint256 amount) external {}

    /// @dev borrows an amount of borrowed asset from AaveV3
    /// @param position the strategy position information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param amount amount of borrowing asset to collateralize
    function borrow(Position memory position, uint256 amount) external {}

    /// @dev repays an amount of borrowed asset to AaveV3
    /// @param position the strategy position information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param amount amount of borrowing asset to repay
    function repay(Position memory position, uint256 amount) external {}
}