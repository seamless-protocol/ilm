// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IVariableDebtToken } from
    "@aave/contracts/interfaces/IVariableDebtToken.sol";
import { ReserveConfiguration } from
    "@aave/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes } from
    "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { USDWadRayMath } from "./math/USDWadRayMath.sol";
import { LoanState, LendingPool } from "../types/DataTypes.sol";

/// @title LoanLogic
/// @notice Contains all logic required for managing the loan position on the Seamless protocol
/// @dev when calling pool functions, `onBehalfOf` is set to `address(this)` which, in most cases,
/// @dev represents the strategy vault contract.
library LoanLogic {
    using USDWadRayMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /// @dev used for availableBorrowsBase and maxWithdrawAmount to decrease them by 0.01%
    /// @dev because precision issues on converting to asset amounts can revert borrow/withdraw on lending pool
    uint256 public constant MAX_AMOUNT_PERCENT = 9999;

    /// @notice collateralizes an amount of the given asset via depositing assets into Seamless lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of collateral asset
    /// @param amount amount of asset to collateralize
    /// @return state loan state after supply call
    function supply(
        LendingPool memory lendingPool,
        IERC20 asset,
        uint256 amount
    ) external returns (LoanState memory state) {
        lendingPool.pool.supply(address(asset), amount, address(this), 0);
        return getLoanState(lendingPool);
    }

    /// @notice withdraws collateral from the lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of collateral asset
    /// @param amount amount of asset to withdraw
    /// @return state loan state after supply call
    function withdraw(
        LendingPool memory lendingPool,
        IERC20 asset,
        uint256 amount
    ) external returns (LoanState memory state) {
        lendingPool.pool.withdraw(address(asset), amount, address(this));
        return getLoanState(lendingPool);
    }

    /// @notice borrows an amount of borrowed asset from the lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of borrowing asset
    /// @param amount amount of asset to borrow
    /// @return state loan state after supply call
    function borrow(
        LendingPool memory lendingPool,
        IERC20 asset,
        uint256 amount
    ) external returns (LoanState memory state) {
        lendingPool.pool.borrow(
            address(asset),
            amount,
            lendingPool.interestRateMode,
            0,
            address(this)
        );
        return getLoanState(lendingPool);
    }

    /// @notice repays an amount of borrowed asset to the lending pool
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset address of borrowing asset
    /// @param amount amount of borrowing asset to repay
    /// @return state loan state after supply call
    function repay(LendingPool memory lendingPool, IERC20 asset, uint256 amount)
        external
        returns (LoanState memory state)
    {
        lendingPool.pool.repay(
            address(asset), amount, lendingPool.interestRateMode, address(this)
        );
        return getLoanState(lendingPool);
    }

    /// @notice calculates the debt, and equity corresponding to an amount of shares
    /// @dev collateral corresponding to shares is just sum of debt and equity
    /// @param state loan state of strategy
    /// @param shares amount of shares
    /// @param totalShares total supply of shares
    /// @return shareDebtUSD amount of debt in USD corresponding to shares
    /// @return shareEquityUSD amount of equity in USD corresponding to shares
    function shareDebtAndEquity(
        LoanState memory state,
        uint256 shares,
        uint256 totalShares
    ) internal pure returns (uint256 shareDebtUSD, uint256 shareEquityUSD) {
        shareDebtUSD = USDWadRayMath.wadToUSD(
            USDWadRayMath.usdToWad(state.debtUSD).wadMul(shares).wadDiv(
                totalShares
            )
        );

        shareEquityUSD = USDWadRayMath.wadToUSD(
            USDWadRayMath.usdToWad(state.collateralUSD).wadMul(shares).wadDiv(
                totalShares
            )
        ) - shareDebtUSD;
    }

    /// @notice returns the current state of loan position on the Seamless Protocol lending pool for the caller's account
    /// @notice all returned values are in USD value
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @return state loan state after supply call
    function getLoanState(LendingPool memory lendingPool)
        internal
        view
        returns (LoanState memory state)
    {
        (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            /* availableBorrowsUSD8 */
            ,
            uint256 currentLiquidationThreshold,
            /* ltv */
            ,
            /* healthFactor */
        ) = lendingPool.pool.getUserAccountData(address(this));

        if (totalCollateralUSD == 0) {
            return LoanState({
                collateralUSD: 0,
                debtUSD: 0,
                maxWithdrawAmount: 0
            });
        }

        uint256 maxWithdrawAmount;
        // This can happen when the debt is already above liquidation trashold
        // (due to collateral asset price fall, borrow asset price raise, or interest increase)
        if (
            totalCollateralUSD
                < PercentageMath.percentDiv(
                    totalDebtUSD, currentLiquidationThreshold
                )
        ) {
            maxWithdrawAmount = 0;
        } else {
            maxWithdrawAmount = totalCollateralUSD
                - PercentageMath.percentDiv(
                    totalDebtUSD, currentLiquidationThreshold
                );
        }

        maxWithdrawAmount =
            PercentageMath.percentMul(maxWithdrawAmount, MAX_AMOUNT_PERCENT);

        return LoanState({
            collateralUSD: totalCollateralUSD,
            debtUSD: totalDebtUSD,
            maxWithdrawAmount: maxWithdrawAmount
        });
    }

    /// @notice returns the available supply for the asset, taking into account defined borrow cap
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param asset asset for which the available supply is returned
    /// @return availableAssetSupply available supply
    function getAvailableAssetSupply(
        LendingPool memory lendingPool,
        IERC20 asset
    ) internal view returns (uint256 availableAssetSupply) {
        DataTypes.ReserveData memory reserveData =
            lendingPool.pool.getReserveData(address(asset));

        uint256 totalBorrow = _getTotalBorrow(reserveData);
        uint256 borrowCap = reserveData.configuration.getBorrowCap();
        uint256 assetUnit = 10 ** reserveData.configuration.getDecimals();
        uint256 avilableUntilBorrowCap = (borrowCap * assetUnit > totalBorrow)
            ? borrowCap * assetUnit - totalBorrow
            : 0;

        uint256 availableLiquidityBase =
            asset.balanceOf(reserveData.aTokenAddress);

        availableAssetSupply =
            Math.min(avilableUntilBorrowCap, availableLiquidityBase);
        return availableAssetSupply;
    }

    /// @notice returns the total amount of borrow for given asset reserve data
    /// @param reserveData reserve data (external type) for the asset
    /// @return totalBorrow total borrowed amount
    function _getTotalBorrow(DataTypes.ReserveData memory reserveData)
        internal
        view
        returns (uint256 totalBorrow)
    {
        uint256 currScaledVariableDebt = IVariableDebtToken(
            reserveData.variableDebtTokenAddress
        ).scaledTotalSupply();
        totalBorrow =
            currScaledVariableDebt.rayMul(reserveData.variableBorrowIndex);
        return totalBorrow;
    }

    /// @notice returns the maximum borrow avialble for the asset in USD terms, taking into account borrow cap and asset supply
    /// @param lendingPool struct which contains lending pool setup (pool address and interest rate mode)
    /// @param debtAsset asset for wich max borrow is returned
    /// @param debtAssetPrice price of the asset
    /// @return maxBorrowUSD maximum available borrow
    function getMaxBorrowUSD(
        LendingPool memory lendingPool,
        IERC20 debtAsset,
        uint256 debtAssetPrice
    ) internal view returns (uint256 maxBorrowUSD) {
        uint256 availableAssetSupply =
            getAvailableAssetSupply(lendingPool, debtAsset);
        uint256 assetDecimals = IERC20Metadata(address(debtAsset)).decimals();
        uint256 availableAssetSupplyUSD =
            availableAssetSupply * debtAssetPrice / (10 ** assetDecimals);

        (,, uint256 availableBorrowsUSD,,,) =
            lendingPool.pool.getUserAccountData(address(this));
        maxBorrowUSD = Math.min(availableBorrowsUSD, availableAssetSupplyUSD);
        maxBorrowUSD =
            PercentageMath.percentMul(maxBorrowUSD, MAX_AMOUNT_PERCENT);
        return maxBorrowUSD;
    }
}
