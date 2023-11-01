// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { LoanLogic } from "./LoanLogic.sol";
import { USDWadRayMath } from "./math/USDWadRayMath.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
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
    /// @param _pool lending pool data
    /// @param _assets addresses of collateral and borrow assets
    /// @param _state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param _targetCR target value of collateral ratio to reach
    /// @param _oracle aave oracle
    /// @param _swapper address of swapper contract
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceTo(
        LendingPool memory _pool,
        StrategyAssets memory _assets,
        LoanState memory _state,
        uint256 _targetCR,
        IPriceOracleGetter _oracle,
        ISwapper _swapper
    ) public returns (uint256 ratio) {
        // current collateral ratio
        ratio = collateralRatioUSD(_state.collateralUSD, _state.debtUSD);

        if (ratio > _targetCR) {
            rebalanceUp(
                _pool, _assets, _state, ratio, _targetCR, _oracle, _swapper
            );
        } else {
            rebalanceDown(
                _pool, _assets, _state, ratio, _targetCR, _oracle, _swapper
            );
        }
    }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param _pool lending pool data
    /// @param _assets addresses of collateral and borrow assets
    /// @param _state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param _currentCR current value of collateral ratio
    /// @param _targetCR target value of collateral ratio to reach
    /// @param _oracle aave oracle
    /// @param _swapper address of swapper contract
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceUp(
        LendingPool memory _pool,
        StrategyAssets memory _assets,
        LoanState memory _state,
        uint256 _currentCR,
        uint256 _targetCR,
        IPriceOracleGetter _oracle,
        ISwapper _swapper
    ) public returns (uint256 ratio) {
        // current collateral ratio
        ratio = _currentCR;

        uint256 debtPriceUSD = _oracle.getAssetPrice(address(_assets.debt));
        uint8 debtDecimals = IERC20Metadata(address(_assets.debt)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor = _swapper.offsetFactor(
            address(_assets.debt), address(_assets.collateral)
        );

        // TODO: add hardcoded number of iterations
        do {
            // debt to reach max LTV in USD
            uint256 borrowAmountUSD = _state.maxBorrowAmount;

            // check if borrowing up to max LTV leads to smaller than  target collateral ratio, and adjust borrowAmountUSD if so
            // TODO: check whether min(maxBorrow, adjustedBorrow) is more efficient
            if (
                collateralRatioUSD(
                    _state.collateralUSD
                        + offsetUSDAmountDown(borrowAmountUSD, offsetFactor),
                    _state.debtUSD + borrowAmountUSD
                ) < _targetCR
            ) {
                // calculate amount of debt needed to reach target collateral
                // ONE_USD - offSetFactor < _targetCR by default/design
                // equation used: B = C - (tCR * D) / (tCR - (1 - O))
                // TODO: move to internal and fuzz this adjustment
                borrowAmountUSD = requiredBorrowUSD(
                    _targetCR,
                    _state.collateralUSD,
                    _state.debtUSD,
                    offsetFactor
                );
            }

            // convert borrowAmount from USD to a borrowAsset amount
            uint256 borrowAmountAsset =
                convertUSDToAsset(borrowAmountUSD, debtPriceUSD, debtDecimals);

            if (borrowAmountAsset == 0) {
                break;
            }

            // borrow _assets from AaveV3 _pool
            LoanLogic.borrow(_pool, _assets.debt, borrowAmountAsset);

            // approve _swapper contract to swap asset
            _assets.debt.approve(address(_swapper), borrowAmountAsset);

            // exchange debtAmountAsset of debt tokens for collateral tokens
            uint256 collateralAmountAsset = _swapper.swap(
                address(_assets.debt),
                address(_assets.collateral),
                borrowAmountAsset,
                payable(address(this))
            );

            // collateralize _assets in AaveV3 _pool
            _state = LoanLogic.supply(
                _pool, _assets.collateral, collateralAmountAsset
            );

            // update collateral ratio value
            ratio = collateralRatioUSD(_state.collateralUSD, _state.debtUSD);
        } while (ratio > _targetCR); // add margin of error on _targetCR allowance
    }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy downwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param _pool lending pool data
    /// @param _assets addresses of collateral and borrow assets
    /// @param _state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param _currentCR current value of collateral ratio
    /// @param _targetCR target value of collateral ratio to reach
    /// @param _oracle aave oracle
    /// @param _swapper address of swapper contract
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceDown(
        LendingPool memory _pool,
        StrategyAssets memory _assets,
        LoanState memory _state,
        uint256 _currentCR,
        uint256 _targetCR,
        IPriceOracleGetter _oracle,
        ISwapper _swapper
    ) public returns (uint256 ratio) {
        uint256 collateralPriceUSD =
            _oracle.getAssetPrice(address(_assets.collateral));

        uint8 collateralDecimals =
            IERC20Metadata(address(_assets.collateral)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor = _swapper.offsetFactor(
            address(_assets.collateral), address(_assets.debt)
        );

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
            LoanLogic.withdraw(_pool, _assets.collateral, collateralAmountAsset);

            // approve _swapper contract to swap asset
            _assets.collateral.approve(address(_swapper), collateralAmountAsset);

            // exchange collateralAmount of collateral tokens for borrow tokens
            uint256 borrowAmountAsset = _swapper.swap(
                address(_assets.collateral),
                address(_assets.debt),
                collateralAmountAsset,
                payable(address(this))
            );

            // repay debt to AaveV3 _pool
            _state = LoanLogic.repay(_pool, _assets.debt, borrowAmountAsset);

            // update collateral ratio value
            ratio = collateralRatioUSD(_state.collateralUSD, _state.debtUSD);
        } while (ratio < _targetCR); // check asymptotic behavior
    }

    /// @notice helper function to calculate collateral ratio
    /// @param collateralUSD collateral value in USD
    /// @param debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
        public
        pure
        returns (uint256 ratio)
    {
        ratio = debtUSD != 0 ? collateralUSD.usdDiv(debtUSD) : 0;
    }

    /// @notice converts a asset amount to its usd value
    /// @param assetAmount amount of asset
    /// @param priceInUSD price of asset in USD
    /// @return usdAmount amount of USD after conversion
    function convertAssetToUSD(
        uint256 assetAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) public pure returns (uint256 usdAmount) {
        usdAmount = assetAmount * priceInUSD / (10 ** assetDecimals);
    }

    /// @notice converts a USD amount to its token value
    /// @param usdAmount amount of USD
    /// @param priceInUSD price of asset in USD
    /// @return assetAmount amount of asset after conversion
    function convertUSDToAsset(
        uint256 usdAmount,
        uint256 priceInUSD,
        uint256 assetDecimals
    ) public pure returns (uint256 assetAmount) {
        if (USD_DECIMALS > assetDecimals) {
            assetAmount = usdAmount.usdDiv(priceInUSD)
                / (10 ** (USD_DECIMALS - assetDecimals));
        } else {
            assetAmount = usdAmount.usdDiv(priceInUSD)
                * (10 ** (assetDecimals - USD_DECIMALS));
        }
    }

    /// @notice helper function to offset amounts by a USD percentage downwards
    /// @param a amount to offset
    /// @param usdOffset offset as a number between 0 -  ONE_USD
    function offsetUSDAmountDown(uint256 a, uint256 usdOffset)
        public
        pure
        returns (uint256 amount)
    {
        // prevent overflows
        if (a <= type(uint256).max / (ONE_USD - usdOffset)) {
            amount = (a * (ONE_USD - usdOffset)) / ONE_USD;
        } else {
            amount = (a / ONE_USD) * (ONE_USD - usdOffset);
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
