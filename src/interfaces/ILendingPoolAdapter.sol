// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { LoanState } from "../types/DataTypes.sol";

/// @title ILendingPoolAdapter
/// @notice Interface for the LendingPoolAdapter contracts used for managing the loan position on the lending protocol
interface ILendingPoolAdapter {
    /// @notice collateralizes an amount of the given asset via depositing assets into the lending pool
    /// @param asset address of collateral asset
    /// @param amount amount of asset to collateralize
    /// @return state loan state after supply call
    function supply(IERC20 asset, uint256 amount) external returns (LoanState memory state);

    /// @notice withdraws collateral from the lending pool
    /// @param asset address of collateral asset
    /// @param amount amount of asset to withdraw
    /// @return state loan state after supply call
    function withdraw(IERC20 asset, uint256 amount) external returns (LoanState memory state);

    /// @notice borrows an amount of borrowed asset from the lending pool
    /// @param asset address of borrowing asset
    /// @param amount amount of asset to borrow
    /// @return state loan state after supply call
    function borrow(IERC20 asset, uint256 amount) external returns (LoanState memory state);

    /// @notice repays an amount of borrowed asset to the lending pool
    /// @param asset address of borrowing asset
    /// @param amount amount of borrowing asset to repay
    /// @return state loan state after supply call
    function repay(IERC20 asset, uint256 amount) external returns (LoanState memory state);

    /// @notice returns the current state of loan position on the lending pool
    /// @notice all returned values are in USD value
    /// @return state includes collateral, debt, maxBorrowAmount and maxWithdrawAmount
    function getLoanState() external returns (LoanState memory state);

    /// @notice sets the interest rate mode used on borrowing from the pool
    /// @dev callable only by owner
    function setInterestRateMode(uint256 interestRateMode) external;
}