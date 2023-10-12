// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { BorrowPoolMock } from "./BorrowPoolMock.sol";
import { LoanLogicMock } from "./LoanLogicMock.sol";
import { USDWadMath } from "../../src/libraries/math/USDWadMath.sol";
import { IOracleMock} from "./IOracleMock.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { CollateralRatio, LoanState } from "../../src/types/DataTypes.sol";

/// @title RebalanceLogicMock
/// @notice Contains all logic required for rebalancing, using mock contracts
library RebalanceLogicMock {
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
        BorrowPoolMock borrowPool,
        CollateralRatio memory collateralRatio,
        LoanState memory loanState,
        IOracleMock oracle,
        ISwapper swapper
    ) external returns (uint256 ratio) {
        // current collateral ratio
        ratio = _collateralRatioUSD(loanState.collateral, loanState.debt);
    
        uint256 debtPriceInUSD = oracle.getAssetPrice(address(loanState.borrowAsset));

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor = swapper.offsetFactor(address(loanState.borrowAsset), address(loanState.collateralAsset));

        do {
            // debt needed to reach max LTV
            uint256 debtAmount = loanState.maxBorrowAmount;

            // check if borrowing up to max LTV leads to smaller than  target collateral ratio, and adjust debtAmount if so
            if (
                _collateralRatioUSD(loanState.collateral + _offsetUSDAmountUp(debtAmount, offsetFactor) , loanState.debt + debtAmount) <
                collateralRatio.target
            ) {
                // calculate amount of debt needed to reach target collateral
                // offSetFactor < collateralRatio.target by default/design
                debtAmount = (loanState.collateral - collateralRatio.target.usdMul(loanState.debt)).usdDiv(
                    collateralRatio.target - (ONE_USD - offsetFactor)
                );
            } 

            // convert debtAmount from USD to a borrowAsset amount
            uint256 debtAmountAsset = _convertUSDToAsset(debtAmount, debtPriceInUSD);

            // borrow assets from AaveV3 pool
            LoanLogicMock.borrow(borrowPool, debtAmountAsset);

            // approve swapper contract to swap asset
            loanState.borrowAsset.approve(address(swapper), debtAmountAsset);

            // exchange debtAmountAsset of debt tokens for collateral tokens
            uint256 collateralAmountAsset = swapper.swap(
                address(loanState.borrowAsset),
                address(loanState.collateralAsset),
                debtAmountAsset,
                payable(address(this))
            );

            // collateralize assets in AaveV3 pool
            loanState = LoanLogicMock.supply(borrowPool, collateralAmountAsset);
            
            // update collateral ratio value
            ratio = _collateralRatioUSD(loanState.collateral, loanState.debt);
        } while (ratio > collateralRatio.target);
    }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy downwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param collateralRatio the collateral ratio information (min, max, target values)
    /// @param loanState the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt, maxLTV)
    /// @param oracle aave oracle
    /// @param swapper address of Swapper contract
    /// @return ratio value of collateralRatio after rebalance
    function rebalanceDown(
        BorrowPoolMock borrowPool,
        CollateralRatio memory collateralRatio,
        LoanState memory loanState,
        IOracleMock oracle,
        ISwapper swapper
    ) external returns (uint256 ratio) {
        // current collateral ratio
        ratio = _collateralRatioUSD(loanState.collateral, loanState.debt);

        uint256 collateralUSDPrice = oracle.getAssetPrice(address(loanState.collateralAsset));

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor = swapper.offsetFactor(address(loanState.borrowAsset), address(loanState.collateralAsset));

        do {
            // maximum amount of collateral to not jeopardize loan health
            uint256 collateralAmount = loanState.maxWithdrawAmount.usdMul(ONE_USD - offsetFactor).usdDiv(ONE_USD);
            
            // check if repaying max collateral will lead to the collateralRatio being more than target, and adjust
            // collateralAmount if so
            if (
                _collateralRatioUSD(loanState.collateral - collateralAmount, loanState.debt - _offsetUSDAmountUp(collateralAmount, offsetFactor)) >
                collateralRatio.target
            ) {
                collateralAmount = (collateralRatio.target.usdMul(loanState.debt) - loanState.collateral).usdDiv(
                    collateralRatio.target.usdMul(ONE_USD - offsetFactor) - ONE_USD
                );
            }

            uint256 collateralAmountAsset = _convertUSDToAsset(collateralAmount, collateralUSDPrice);

            // withdraw collateral tokens from Aave pool
            LoanLogicMock.withdraw(borrowPool, collateralAmountAsset);
            
            // approve swapper contract to swap asset
            loanState.collateralAsset.approve(address(swapper), collateralAmountAsset);

            // exchange collateralAmount of collateral tokens for debt tokens
            uint256 debtAmount = swapper.swap(
                address(loanState.collateralAsset),
                address(loanState.borrowAsset),
                collateralAmountAsset,
                payable(address(this))
            );

            // repay debt to AaveV3 pool
            loanState = LoanLogicMock.repay(borrowPool, debtAmount);

            // update collateral ratio value
            ratio = _collateralRatioUSD(loanState.collateral, loanState.debt);
        } while (ratio < collateralRatio.target);
    }

    /// @notice helper function to offset amounts by a USD percentage downwards
    /// @param a amount to offset
    /// @param usdOffset offset as a number between 0 -  ONE_USD
    function _offsetUSDAmountDown(uint256 a, uint256 usdOffset) internal pure returns (uint256 amount) {
        amount = (a.wadMul(usdOffset)).wadDiv(ONE_TOKEN);
    }

    /// @notice helper function to offset amounts by a USD percentage upnwards
    /// @param a amount to offset
    /// @param usdOffset offset as a number between 0 -  ONE_USD
    function _offsetUSDAmountUp(uint256 a, uint256 usdOffset) internal pure returns (uint256 amount) {
        amount = a * (ONE_USD - usdOffset) / ONE_USD;
    }

    /// @notice helper function to calculate collateral ratio
    /// @param collateralUSD collateral value in USD
    /// @param debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function _collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD) internal pure returns (uint256 ratio) {
        ratio = debtUSD != 0 ? collateralUSD.usdDiv(debtUSD) : 0;
    }

    /// @notice converts a asset amount to its usd value
    /// @param assetAmount amount of asset
    /// @param priceInUSD price of asset in USD
    /// @return usdAmount amount of USD after conversion
    function _convertAssetToUSD(uint256 assetAmount, uint256 priceInUSD) internal pure returns (uint256 usdAmount) {
        usdAmount = USDWadMath.wadToUSD(((USDWadMath.usdToWad(priceInUSD)).wadMul(assetAmount)));
    }

    /// @notice converts a USD amount to its token value
    /// @param usdAmount amount of USD
    /// @param priceInUSD price of asset in USD
    /// @return assetAmount amount of asset after conversion
    function _convertUSDToAsset(uint256 usdAmount, uint256 priceInUSD) internal pure returns (uint256 assetAmount) {
        assetAmount = (usdAmount / priceInUSD);
    }
}
