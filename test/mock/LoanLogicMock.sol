// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BorrowPoolMock } from "./BorrowPoolMock.sol";
import { LoanState } from "../../src/types/DataTypes.sol";

/// @title LoanLogicMock
/// @notice Contains all logic required for managing the loan position
library LoanLogicMock {
    /// @dev collateralizes an amount of underlying asset in AaveV3 via depositing assets into Aave lending pool
    /// @param borrowPool pool to borrow from
    /// @param amount amount of asset to collateralize
    /// @return state loan state after supply call
    function supply(BorrowPoolMock borrowPool, uint256 amount) public returns (LoanState memory state) {
        borrowPool.supply(address(this), amount);

        state = LoanState({
            collateralAsset: borrowPool.collateralAsset(),
            borrowAsset: borrowPool.borrowAsset(),
            collateral: borrowPool.collateral(address(this)),
            debt: borrowPool.debt(address(this)),
            maxBorrowAmount: maxBorrowAvailable(borrowPool, address(this)),
            maxWithdrawAmount: maxWithdrawAvailable(borrowPool, address(this))
        });
    }

    /// @dev withdrawing collateral from the lending pool
    /// @param borrowPool pool to borrow from
    /// @param amount amount of asset to withdraw
    /// @return state loan state after withdraw call
    function withdraw(BorrowPoolMock borrowPool, uint256 amount) public returns (LoanState memory state) {
        borrowPool.withdraw(address(this), amount);

        state = LoanState({
            collateralAsset: borrowPool.collateralAsset(),
            borrowAsset: borrowPool.borrowAsset(),
            collateral: borrowPool.collateral(address(this)),
            debt: borrowPool.debt(address(this)),
            maxBorrowAmount: maxBorrowAvailable(borrowPool, address(this)),
            maxWithdrawAmount: maxWithdrawAvailable(borrowPool, address(this))
        });
    }

    /// @dev borrows an amount of borrowed asset from AaveV3
    /// @param borrowPool pool to borrow from
    /// @param amount amount of asset to borrow
    /// @return state loan state after borrow call
    function borrow(BorrowPoolMock borrowPool, uint256 amount) public returns (LoanState memory state) {
        borrowPool.borrow(address(this), amount);

        state = LoanState({
            collateralAsset: borrowPool.collateralAsset(),
            borrowAsset: borrowPool.borrowAsset(),
            collateral: borrowPool.collateral(address(this)),
            debt: borrowPool.debt(address(this)),
            maxBorrowAmount: maxBorrowAvailable(borrowPool, address(this)),
            maxWithdrawAmount: maxWithdrawAvailable(borrowPool, address(this))
        });
    }

    /// @dev repays an amount of borrowed asset to AaveV3
    /// @param borrowPool pool to borrow from
    /// @param amount amount of borrowing asset to repay
    /// @return state loan state after repay call
    function repay(BorrowPoolMock borrowPool, uint256 amount) public returns (LoanState memory state) {
        borrowPool.repay(address(this), amount);

        state = LoanState({
            collateralAsset: borrowPool.collateralAsset(),
            borrowAsset: borrowPool.borrowAsset(),
            collateral: borrowPool.collateral(address(this)),
            debt: borrowPool.debt(address(this)),
            maxBorrowAmount: maxBorrowAvailable(borrowPool, address(this)),
            maxWithdrawAmount: maxWithdrawAvailable(borrowPool, address(this))
        });
    }

    /// @dev returns the maximum value of available borrowing in USD for an account
    /// @param borrowPool pool to borrow from
    /// @param account address of an acount
    /// @return uint256 available value to borrow in USD
    function maxBorrowAvailable(BorrowPoolMock borrowPool, address account) public view returns (uint256) {
        return borrowPool.maxBorrowAvailable(account);
    }

    /// @dev returns the maximum value of collateral available to withdraw in USD for an account
    /// @param borrowPool pool to borrow from
    /// @param account address of an acount
    /// @return uint256 available value to withdraw in USD
    function maxWithdrawAvailable(BorrowPoolMock borrowPool, address account) public view returns (uint256) {
        return borrowPool.maxWithdrawAvailable(account);
    }

    /// @dev returns the loan state of a given account for the borrow pool
    /// @param borrowPool instance of borrowPool to check loan state from
    /// @param account account which loantate corresponds to
    /// @return state loan state of account in borrowPool
    function loanState(BorrowPoolMock borrowPool, address account) public view returns (LoanState memory state) {
        state = LoanState({
            collateralAsset: borrowPool.collateralAsset(),
            borrowAsset: borrowPool.borrowAsset(),
            collateral: borrowPool.collateral(account),
            debt: borrowPool.debt(account),
            maxBorrowAmount: maxBorrowAvailable(borrowPool, account),
            maxWithdrawAmount: maxWithdrawAvailable(borrowPool, account)
        });
    }
}
