// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { ConversionMath } from "./ConversionMath.sol";
import { USDWadRayMath } from "./USDWadRayMath.sol";
import { LoanState } from "../../types/DataTypes.sol";

library RebalanceMath {
    using USDWadRayMath for uint256;

    uint256 internal constant ONE_USD = 1e8;

    /// @notice helper function to calculate collateral ratio
    /// @param collateralUSD collateral value in USD
    /// @param debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
        internal
        pure
        returns (uint256 ratio)
    {
        ratio = debtUSD != 0 ? collateralUSD.usdDiv(debtUSD) : type(uint256).max;
    }

    /// @notice helper function to offset amounts by a USD percentage downwards
    /// @param a amount to offset
    /// @param offsetUSD offset as a number between 0 -  ONE_USD
    function offsetUSDAmountDown(uint256 a, uint256 offsetUSD)
        internal
        pure
        returns (uint256 amount)
    {
        // prevent overflows
        if (a <= type(uint256).max / (ONE_USD - offsetUSD)) {
            amount = (a * (ONE_USD - offsetUSD)) / ONE_USD;
        } else {
            amount = (a / ONE_USD) * (ONE_USD - offsetUSD);
        }
    }

    /// @notice calculates the total required borrow amount in order to reach a target collateral ratio value
    /// @param targetCR target collateral ratio value
    /// @param collateralUSD current collateral value in USD
    /// @param debtUSD current debt value in USD
    /// @param offsetFactor expected loss to DEX fees and slippage expressed as a value from 0 - ONE_USD
    /// @return amount required borrow amount
    function requiredBorrowUSD(
        uint256 targetCR,
        uint256 collateralUSD,
        uint256 debtUSD,
        uint256 offsetFactor
    ) internal pure returns (uint256 amount) {
        return (collateralUSD - targetCR.usdMul(debtUSD)).usdDiv(
            targetCR - (ONE_USD - offsetFactor)
        );
    }

    /// @notice calculates the total required collateral amount in order to reach a target collateral ratio value
    /// @param targetCR target collateral ratio value
    /// @param collateralUSD current collateral value in USD
    /// @param debtUSD current debt value in USD
    /// @param offsetFactor expected loss to DEX fees and slippage expressed as a value from 0 - ONE_USD
    /// @return amount required collateral amount
    function requiredCollateralUSD(
        uint256 targetCR,
        uint256 collateralUSD,
        uint256 debtUSD,
        uint256 offsetFactor
    ) internal pure returns (uint256 amount) {
        return (
            amount = (targetCR.usdMul(debtUSD) - collateralUSD).usdDiv(
                targetCR.usdMul(ONE_USD - offsetFactor) - ONE_USD
            )
        );
    }

    /// @notice determines the collateral asset amount needed for a rebalance down cycle
    /// @param state loan state
    /// @param neededCollateralUSD collateral needed for overall operation in USD
    /// @param collateralPriceUSD price of collateral in USD
    /// @param collateralDecimals decimals of collateral token
    /// @return collateralAmountAsset amount of collateral asset needed fo the current rebalance down cycle
    function calculateCollateralAsset(
        LoanState memory state,
        uint256 neededCollateralUSD,
        uint256 collateralPriceUSD,
        uint256 collateralDecimals
    ) internal pure returns (uint256 collateralAmountAsset) {
        // maximum amount of collateral to not jeopardize loan health in USD
        uint256 collateralAmountUSD = state.maxWithdrawAmount;

        // handle cases where debt is less than maxWithdrawAmount possible
        if (state.debtUSD < state.maxWithdrawAmount) {
            collateralAmountUSD = state.debtUSD;
        }

        // if less than the max collateral amount possible is needed,
        // use the amount that is required to reach targetCR
        collateralAmountUSD = collateralAmountUSD < neededCollateralUSD
            ? collateralAmountUSD
            : neededCollateralUSD;

        return ConversionMath.convertUSDToAsset(
            collateralAmountUSD, collateralPriceUSD, collateralDecimals
        );
    }
}
