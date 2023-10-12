// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { DataTypes } from "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import { PercentageMath } from "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { LoanState } from "../types/DataTypes.sol";

/// @title LoanLogic
/// @notice Contains all logic required for managing the loan position on the Seamless protocol
/// @dev when calling pool functions, `onBehalfOf` is set to `address(this)` which, in most cases,
/// @dev represents the strategy vault contract.
library LoanLogic {

    /// @notice address of the Seamless protocol pool address provider
    /// @dev docs reference: https://docs.seamlessprotocol.com/technical/smart-contracts
    IPoolAddressesProvider public constant poolAddressProvider = IPoolAddressesProvider(0x0E02EB705be325407707662C6f6d3466E939f3a0);
    
    // TODO: check if we would always want variable rate mode
    // TODO: check if we want to write just `2` instead of importing aave `DataTypes` because of this
    /// @notice The interest rate mode of the debt
    uint256 public constant interestRateMode = uint256(DataTypes.InterestRateMode.VARIABLE);

    /// @dev collateralizes an amount of underlying asset in AaveV3 via depositing assets into Aave lending pool
    /// @param asset address of collateral asset
    /// @param amount amount of asset to collateralize
    /// @return state loan state after supply call
    function supply(IERC20 asset, uint256 amount) external returns (LoanState memory state) {
        IPool pool = IPool(poolAddressProvider.getPool());
        pool.supply(address(asset), amount, address(this), 0);
        state = getLoanState();
    }

    /// @dev withdrawing collateral from the lending pool
    /// @param asset address of collateral asset
    /// @param amount amount of asset to withdraw
    /// @return state loan state after supply call
    function withdraw(IERC20 asset, uint256 amount) external returns (LoanState memory state) {
        IPool pool = IPool(poolAddressProvider.getPool());
        pool.withdraw(address(asset), amount, address(this));
        state = getLoanState();
    }

    /// @dev borrows an amount of borrowed asset from AaveV3
    /// @param asset address of borrowing asset
    /// @param amount amount of asset to borrow
    /// @return state loan state after supply call
    function borrow(IERC20 asset, uint256 amount) external returns (LoanState memory state) {
        IPool pool = IPool(poolAddressProvider.getPool());
        pool.borrow(address(asset), amount, interestRateMode, 0, address(this));
        state = getLoanState();
    }

    /// @dev repays an amount of borrowed asset to AaveV3
    /// @param asset address of borrowing asset
    /// @param amount amount of borrowing asset to repay
    /// @return state loan state after supply call
    function repay(IERC20 asset, uint256 amount) external returns (LoanState memory state) {
        IPool pool = IPool(poolAddressProvider.getPool());
        pool.repay(address(asset), amount, interestRateMode, address(this));
        state = getLoanState();
    }

    /// 
    function getLoanState() public view returns (LoanState memory state) {
        IPool pool = IPool(poolAddressProvider.getPool());
        
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            /* currentLiquidationThreshold */,
            uint256 ltv,
            /* healthFactor */
        ) = pool.getUserAccountData(address(this));

        uint256 maxWithdrawAmount = 
            totalCollateralBase - PercentageMath.percentDiv(totalDebtBase, ltv);

        return LoanState({
            // TODO: what to return here on collateralAsset and borrowedAsset
            // TODO: should we change the LoanState struct and get assets from other source?
            collateralAsset: IERC20(address(0)),
            borrowedAsset: IERC20(address(0)),
            collateral: totalCollateralBase,
            debt: totalDebtBase,
            maxBorrowAmount: availableBorrowsBase,
            maxWithdrawAmount: maxWithdrawAmount
        });
    }   
}