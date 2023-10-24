// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { DataTypes } from "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import { PercentageMath } from "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { LoanState, LendingPool } from "../types/DataTypes.sol";

import { LoanState } from "../types/DataTypes.sol";

/// @title LoanLogic
/// @notice Contains all logic required for managing the loan position on the Seamless protocol
/// @dev when calling pool functions, `onBehalfOf` is set to `address(this)` which, in most cases,
/// @dev represents the strategy vault contract.
library LoanLogic {
    /// @dev used for availableBorrowsBase and maxWithdrawAmount to decrease them by 0.01%
    /// @dev because precision issues on converting to asset amounts can revert borrow/withdraw on lending pool
    uint256 public constant MAX_AMOUNT_PERCENT = 99_99;

    /// @notice collateralizes an amount of the given asset via depositing assets into Seamless lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of collateral asset
    /// @param amount amount of asset to collateralize
    /// @return state loan state after supply call
    function supply(LendingPool memory lendingPool, IERC20 asset, uint256 amount) external returns(LoanState memory state) {
        lendingPool.pool.supply(address(asset), amount, address(this), 0);
        return getLoanState(lendingPool);
    }

    /// @notice withdraws collateral from the lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of collateral asset
    /// @param amount amount of asset to withdraw
    /// @return state loan state after supply call
    function withdraw(LendingPool memory lendingPool, IERC20 asset, uint256 amount) external returns(LoanState memory state) {
        lendingPool.pool.withdraw(address(asset), amount, address(this));
        return getLoanState(lendingPool);
    }

    /// @notice borrows an amount of borrowed asset from the lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of borrowing asset
    /// @param amount amount of asset to borrow
    /// @return state loan state after supply call
    function borrow(LendingPool memory lendingPool, IERC20 asset, uint256 amount) external returns(LoanState memory state) {
        lendingPool.pool.borrow(address(asset), amount, lendingPool.interestRateMode, 0, address(this));
        return getLoanState(lendingPool);
    }

    /// @notice repays an amount of borrowed asset to the lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of borrowing asset
    /// @param amount amount of borrowing asset to repay
    /// @return state loan state after supply call
    function repay(LendingPool memory lendingPool, IERC20 asset, uint256 amount) external returns(LoanState memory state) {
        lendingPool.pool.repay(address(asset), amount, lendingPool.interestRateMode, address(this));
        return getLoanState(lendingPool);
    }

    /// @notice returns the current state of loan position on the Seamless Protocol lending pool for the caller's account
    /// @notice all returned values are in USD value
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)  
    /// @return state loan state after supply call
    function getLoanState(LendingPool memory lendingPool) internal view returns(LoanState memory state) {        
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            /* currentLiquidationThreshold */,
            uint256 ltv,
            /* healthFactor */
        ) = lendingPool.pool.getUserAccountData(address(this));

        uint256 maxWithdrawAmount = 
            totalCollateralBase - PercentageMath.percentDiv(totalDebtBase, ltv);


        availableBorrowsBase = PercentageMath.percentMul(availableBorrowsBase, MAX_AMOUNT_PERCENT);
        maxWithdrawAmount = PercentageMath.percentMul(maxWithdrawAmount, MAX_AMOUNT_PERCENT);

        return LoanState({
            collateralUSD: totalCollateralBase,
            debtUSD: totalDebtBase,
            maxBorrowAmount: availableBorrowsBase,
            maxWithdrawAmount: maxWithdrawAmount
        });
    }   
}
