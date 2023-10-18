// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { LendingPool, LoanState } from "../types/DataTypes.sol";

/// @title LoanLogic
/// @notice Contains all logic required for managing the loan position 
library LoanLogic {
    /// @dev collateralizes an amount of underlying asset in AaveV3 via depositing assets into Aave lending pool
    /// @param asset address of collateral asset
    /// @param amount amount of asset to collateralize
    function supply(IERC20 asset, uint256 amount) external {}

    /// @dev withdrawing collateral from the lending pool
    /// @param asset address of collateral asset
    /// @param amount amount of asset to withdraw
    function withdraw(IERC20 asset, uint256 amount) external {}

    /// @dev borrows an amount of borrowed asset from AaveV3
    /// @param asset address of borrowing asset
    /// @param amount amount of asset to borrow
    function borrow(IERC20 asset, uint256 amount) external {}

    /// @dev repays an amount of borrowed asset to AaveV3
    /// @param asset address of borrowing asset
    /// @param amount amount of borrowing asset to repay
    function repay(IERC20 asset, uint256 amount) external {}

    /// @dev returns the maximum value of available borrowing in USD for an account
    /// @param account address of an acount
    /// @return uint256 available value to borrow in USD
    function maxBorrowAvailable(address account) external view returns(uint256) {}

    /// @dev returns the maximum value of collateral available to withdraw in USD for an account
    /// @param account address of an acount
    /// @return uint256 available value to withdraw in USD
    function maxWithdrawAvailable(address account) external view returns(uint256) {}

    /// @notice returns the current state of loan position on the Seamless Protocol lending pool
    /// @notice all returned values are in USD value
    /// @return state loan state after supply call
    function getLoanState(LendingPool memory lendingPool) internal view returns(LoanState memory state) {}
}