// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { LoanLogic } from "./LoanLogic.sol";
import { USDWadRayMath } from "./math/USDWadRayMath.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
import { LoopStrategyStorage as Storage } from
    "../storage/LoopStrategyStorage.sol";
import { LendingPool, LoanState, StrategyAssets } from "../types/DataTypes.sol";

/// @title RebalanceLogic
/// @notice Contains all logic required for rebalancing
library RebalanceLogic {
    using USDWadRayMath for uint256;

    /// @dev ONE in USD scale and in WAD scale
    uint256 internal constant ONE_USD = 1e8;
    uint256 internal constant ONE_WAD = USDWadRayMath.WAD;

    /// @dev decimals of USD prices as per _oracle, and WAD decimals
    uint8 internal constant USD_DECIMALS = 8;
    uint8 internal constant WAD_DECIMALS = 18;

    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param $ the storage state of LendingStrategyStorage
    /// @param _state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param _targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceTo(
        Storage.Layout storage $,
        LoanState memory _state,
        uint256 _targetCR
    ) public returns (uint256 ratio) {
        // current collateral ratio
        ratio = collateralRatioUSD(_state.collateralUSD, _state.debtUSD);

        if (ratio > _targetCR) {
            return rebalanceUp($, _state, ratio, _targetCR);
        } else {
            return rebalanceDown($, _state, ratio, _targetCR);
        }
    }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev "upwards" in this context means reducing collateral ratio, thereby _increasing_ exposure
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param $ the storage state of LendingStrategyStorage
    /// @param _state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param _currentCR current value of collateral ratio
    /// @param _targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceUp(
        Storage.Layout storage $,
        LoanState memory _state,
        uint256 _currentCR,
        uint256 _targetCR
    ) public returns (uint256 ratio) {
        // current collateral ratio
        ratio = _currentCR;

        uint256 debtPriceUSD = $.oracle.getAssetPrice(address($.assets.debt));
        uint8 debtDecimals = IERC20Metadata(address($.assets.debt)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.debt, $.assets.collateral);

        uint256 margin = _targetCR * $.ratioMargin / ONE_USD;
        uint256 count;

        do {
            // maximum borrowable amount in USD
            uint256 borrowAmountUSD = LoanLogic.getMaxBorrowUSD(
                $.lendingPool,
                $.assets.debt,
                $.oracle.getAssetPrice(address($.assets.debt))
            );

            {
                // calculate how much borrow amount in USD is needed to reach
                // targetCR
                uint256 neededBorrowUSD = requiredBorrowUSD(
                    _targetCR,
                    _state.collateralUSD,
                    _state.debtUSD,
                    offsetFactor
                );

                // if less than the max borrow amount possible is needed to reach LTV,
                // use the amount that is required to reach targetCR
                borrowAmountUSD = borrowAmountUSD < neededBorrowUSD
                    ? borrowAmountUSD
                    : neededBorrowUSD;
            }

            // convert borrowAmount from USD to a borrowAsset amount
            uint256 borrowAmountAsset =
                convertUSDToAsset(borrowAmountUSD, debtPriceUSD, debtDecimals);

            if (borrowAmountAsset == 0) {
                break;
            }

            // borrow _assets from AaveV3 _pool
            LoanLogic.borrow($.lendingPool, $.assets.debt, borrowAmountAsset);

            // approve _swapper contract to swap asset
            $.assets.debt.approve(address($.swapper), borrowAmountAsset);

            // exchange debtAmountAsset of debt tokens for collateral tokens
            uint256 collateralAmountAsset = $.swapper.swap(
                $.assets.debt,
                $.assets.collateral,
                borrowAmountAsset,
                payable(address(this))
            );

            if (collateralAmountAsset == 0) {
                break;
            }

            // collateralize _assets in AaveV3 _pool
            _state = LoanLogic.supply(
                $.lendingPool, $.assets.collateral, collateralAmountAsset
            );

            // update collateral ratio value
            ratio = collateralRatioUSD(_state.collateralUSD, _state.debtUSD);

            if (++count > $.maxIterations) {
                break;
            }
        } while (_targetCR + margin < ratio);
    }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy downwards
    /// @dev "downards" in this context means increasing collateral ratio, thereby _decreasing_ exposure
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param $ the storage state of LendingStrategyStorage
    /// @param _state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param _currentCR current value of collateral ratio
    /// @param _targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceDown(
        Storage.Layout storage $,
        LoanState memory _state,
        uint256 _currentCR,
        uint256 _targetCR
    ) public returns (uint256 ratio) {
        uint256 collateralPriceUSD =
            $.oracle.getAssetPrice(address($.assets.collateral));

        uint8 collateralDecimals =
            IERC20Metadata(address($.assets.collateral)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.collateral, $.assets.debt);

        uint256 margin = _targetCR * $.ratioMargin / ONE_USD;
        uint256 count;

        do {
            // current collateral ratio
            ratio = _currentCR;

            // maximum amount of collateral to not jeopardize loan health in USD
            uint256 collateralAmountUSD = _state.maxWithdrawAmount;

            // handle cases where debt is less than maxWithdrawAmount possible
            if (_state.debtUSD < _state.maxWithdrawAmount) {
                collateralAmountUSD = _state.debtUSD;
            }

            // check if repaying max collateral will lead to the collateralRatio being more than target, and adjust
            // collateralAmount if so
            if (
                collateralRatioUSD(
                    _state.collateralUSD - collateralAmountUSD,
                    _state.debtUSD
                        - offsetUSDAmountDown(collateralAmountUSD, offsetFactor)
                ) > _targetCR
            ) {
                collateralAmountUSD = (
                    _targetCR.usdMul(_state.debtUSD) - _state.collateralUSD
                ).usdDiv(_targetCR.usdMul(ONE_USD - offsetFactor) - ONE_USD);
            }

            uint256 collateralAmountAsset = convertUSDToAsset(
                collateralAmountUSD, collateralPriceUSD, collateralDecimals
            );

            if (collateralAmountAsset == 0) {
                break;
            }

            // withdraw collateral tokens from Aave _pool
            LoanLogic.withdraw(
                $.lendingPool, $.assets.collateral, collateralAmountAsset
            );

            // approve _swapper contract to swap asset
            $.assets.collateral.approve(
                address($.swapper), collateralAmountAsset
            );

            // exchange collateralAmount of collateral tokens for borrow tokens
            uint256 borrowAmountAsset = $.swapper.swap(
                $.assets.collateral,
                $.assets.debt,
                collateralAmountAsset,
                payable(address(this))
            );

            if (borrowAmountAsset == 0) {
                break;
            }

            // repay debt to AaveV3 _pool
            _state =
                LoanLogic.repay($.lendingPool, $.assets.debt, borrowAmountAsset);

            // update collateral ratio value
            ratio = collateralRatioUSD(_state.collateralUSD, _state.debtUSD);
            if (++count > $.maxIterations) {
                break;
            }
        } while (ratio + margin < _targetCR);
    }

    /// @notice helper function to calculate collateral ratio
    /// @param _collateralUSD collateral value in USD
    /// @param _debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function collateralRatioUSD(uint256 _collateralUSD, uint256 _debtUSD)
        public
        pure
        returns (uint256 ratio)
    {
        ratio =
            _debtUSD != 0 ? _collateralUSD.usdDiv(_debtUSD) : type(uint256).max;
    }

    /// @notice converts a asset amount to its usd value
    /// @param _assetAmount amount of asset
    /// @param _priceInUSD price of asset in USD
    /// @return usdAmount amount of USD after conversion
    function convertAssetToUSD(
        uint256 _assetAmount,
        uint256 _priceInUSD,
        uint256 _assetDecimals
    ) public pure returns (uint256 usdAmount) {
        usdAmount = _assetAmount * _priceInUSD / (10 ** _assetDecimals);
    }

    /// @notice converts a USD amount to its token value
    /// @param _usdAmount amount of USD
    /// @param _priceInUSD price of asset in USD
    /// @return assetAmount amount of asset after conversion
    function convertUSDToAsset(
        uint256 _usdAmount,
        uint256 _priceInUSD,
        uint256 _assetDecimals
    ) public pure returns (uint256 assetAmount) {
        if (USD_DECIMALS > _assetDecimals) {
            assetAmount = _usdAmount.usdDiv(_priceInUSD)
                / (10 ** (USD_DECIMALS - _assetDecimals));
        } else {
            assetAmount = _usdAmount.usdDiv(_priceInUSD)
                * (10 ** (_assetDecimals - USD_DECIMALS));
        }
    }

    /// @notice helper function to offset amounts by a USD percentage downwards
    /// @param _a amount to offset
    /// @param _offsetUSD offset as a number between 0 -  ONE_USD
    function offsetUSDAmountDown(uint256 _a, uint256 _offsetUSD)
        public
        pure
        returns (uint256 amount)
    {
        // prevent overflows
        if (_a <= type(uint256).max / (ONE_USD - _offsetUSD)) {
            amount = (_a * (ONE_USD - _offsetUSD)) / ONE_USD;
        } else {
            amount = (_a / ONE_USD) * (ONE_USD - _offsetUSD);
        }
    }

    /// @notice calculates the total required borrow amount in order to reach a target collateral ratio value
    /// @param _targetCR target collateral ratio value
    /// @param _collateralUSD current collateral value in USD
    /// @param _debtUSD current debt value in USD
    /// @param _offsetFactor expected loss to DEX fees and slippage expressed as a value from 0 - ONE_USD
    /// @return amount required borrow amount
    function requiredBorrowUSD(
        uint256 _targetCR,
        uint256 _collateralUSD,
        uint256 _debtUSD,
        uint256 _offsetFactor
    ) public pure returns (uint256 amount) {
        return (_collateralUSD - _targetCR.usdMul(_debtUSD)).usdDiv(
            _targetCR - (ONE_USD - _offsetFactor)
        );
    }
}
