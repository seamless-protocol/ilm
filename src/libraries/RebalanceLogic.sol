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

    /// @notice performs a rebalance operation after supplying an asset amount to the lending pool
    /// @param $ the storage state of LendingStrategyStorage
    /// @param state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param assets amount of assets to supply in tokens
    function rebalanceAfterSupply(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 assets
    ) external {
        uint256 prevCollateralRatio =
            collateralRatioUSD(state.collateralUSD, state.debtUSD);

        state = LoanLogic.supply($.lendingPool, $.assets.collateral, assets);

        uint256 afterCollateralRatio =
            collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (prevCollateralRatio == type(uint256).max) {
            rebalanceTo($, state, 0, $.collateralRatioTargets.target);
        } else if (
            afterCollateralRatio
                > $.collateralRatioTargets.maxForDepositRebalance
        ) {
            uint256 rebalanceToRatio = prevCollateralRatio;
            if (
                $.collateralRatioTargets.maxForDepositRebalance
                    > rebalanceToRatio
            ) {
                rebalanceToRatio =
                    $.collateralRatioTargets.maxForDepositRebalance;
            }

            rebalanceTo($, state, 0, rebalanceToRatio);
        }
    }

    /// @notice performs a rebalance operation before withdrawing an equity asset amount from the lending pool
    /// @param $ the storage state of LendingStrategyStorage
    /// @param state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param shareDebtUSD amount of debt in USD corresponding to shares
    /// @param shareEquityUSD amount of equity in USD corresponding to shares
    /// @return shareEquityAsset amount of equity in asset corresponding to shares
    function rebalanceBeforeWithdraw(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 shareDebtUSD,
        uint256 shareEquityUSD
    ) external returns (uint256 shareEquityAsset) {
        // if all shares are being withdrawn, then their debt is the strategy debt
        // so in that case the redeemer incurs the full cost of paying back the debt
        // and is left with the remaining equity
        if (state.debtUSD == shareDebtUSD) {
            // pay back the debt corresponding to the shares
            rebalanceDownToDebt($, state, state.debtUSD - shareDebtUSD);

            state = LoanLogic.getLoanState($.lendingPool);
            shareEquityUSD = state.collateralUSD - state.debtUSD;
        }
        //check if withdrawal would lead to a collateral below minimum acceptable level
        // if yes, rebalance until share debt is repaid, and decrease remaining share equity
        // by equity cost of rebalance
        else if (
            collateralRatioUSD(
                state.collateralUSD - shareEquityUSD, state.debtUSD
            ) < $.collateralRatioTargets.minForWithdrawRebalance
        ) {
            if (
                state.collateralUSD
                    > $.collateralRatioTargets.minForWithdrawRebalance.usdMul(
                        state.debtUSD
                    )
            ) {
                // amount of equity in USD value which may be withdrawn from
                // strategy without driving the collateral ratio below
                // the minForWithdrawRebalance limit, thereby not requiring
                // a rebalance operation
                uint256 freeEquityUSD = state.collateralUSD
                    - $.collateralRatioTargets.minForWithdrawRebalance.usdMul(
                        state.debtUSD
                    );

                // adjust share debt to account for the free equity - since
                // some equity may be withdrawn freely, not all the debt has to be
                // repaid
                shareDebtUSD = shareDebtUSD
                    - freeEquityUSD.usdMul(shareDebtUSD).usdDiv(
                        shareEquityUSD + shareDebtUSD - freeEquityUSD
                    );
            }

            uint256 initialEquityUSD = state.collateralUSD - state.debtUSD;

            // pay back the adjusted debt corresponding to the shares
            rebalanceDownToDebt($, state, state.debtUSD - shareDebtUSD);

            state = LoanLogic.getLoanState($.lendingPool);

            // shares lose equity equal to the amount of equity lost for
            // the rebalance to pay the adjusted debt
            shareEquityUSD -=
                initialEquityUSD - (state.collateralUSD - state.debtUSD);
        }

        // convert equity to collateral asset
        shareEquityAsset = convertUSDToAsset(
            shareEquityUSD,
            $.oracle.getAssetPrice(address($.assets.collateral)),
            IERC20Metadata(address($.assets.collateral)).decimals()
        );

        // withdraw and transfer equity asset amount
        LoanLogic.withdraw($.lendingPool, $.assets.collateral, shareEquityAsset);
    }

    /// @notice performs all operations necessary to rebalance the loan state of the strategy upwards
    /// @dev note that the current collateral/debt values are expected to be given in underlying value (USD)
    /// @param $ the storage state of LendingStrategyStorage
    /// @param state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param withdrawalUSD amount of USD withdrawn - used to project post-collateral-withdrawal collateral ratios (useful in strategy share redemptions)
    /// @param targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceTo(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 withdrawalUSD,
        uint256 targetCR
    ) public returns (uint256 ratio) {
        // current collateral ratio
        ratio = collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (ratio > targetCR) {
            return rebalanceUp($, state, ratio, targetCR);
        } else {
            return rebalanceDown($, state, withdrawalUSD, ratio, targetCR);
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

                // if less than the max borrow amount possible is needed,
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
    /// @param state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param withdrawalUSD amount of USD withdrawn - used to project post-collateral-withdrawal collateral ratios (useful in strategy share redemptions)
    /// @param currentCR current value of collateral ratio
    /// @param targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceDown(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 withdrawalUSD,
        uint256 currentCR,
        uint256 targetCR
    ) public returns (uint256 ratio) {
        uint256 collateralPriceUSD =
            $.oracle.getAssetPrice(address($.assets.collateral));

        uint8 collateralDecimals =
            IERC20Metadata(address($.assets.collateral)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.collateral, $.assets.debt);

        uint256 margin = targetCR * $.ratioMargin / ONE_USD;
        uint256 count;

        // adjust collateralUSD in state by withdrawalUSD
        state.collateralUSD -= withdrawalUSD;

        do {
            // current collateral ratio
            ratio = currentCR;

            uint256 collateralAmountAsset = calculateCollateralAsset(
                state,
                requiredCollateralUSD(
                    targetCR, state.collateralUSD, state.debtUSD, offsetFactor
                ),
                collateralPriceUSD,
                collateralDecimals
            );

            if (collateralAmountAsset == 0) {
                break;
            }

            uint256 borrowAmountAsset =
                withdrawAndSwapCollateral($, collateralAmountAsset);

            if (borrowAmountAsset == 0) {
                break;
            }

            // repay debt to AaveV3 _pool
            state =
                LoanLogic.repay($.lendingPool, $.assets.debt, borrowAmountAsset);

            // adjust collateralUSD in state by withdrawalUSD
            state.collateralUSD -= withdrawalUSD;

            // update collateral ratio value
            ratio = collateralRatioUSD(state.collateralUSD, state.debtUSD);

            if (++count > $.maxIterations) {
                break;
            }
        } while (ratio + margin < targetCR);
    }

    /// @notice rebalances downwards until a debt amount is reached
    /// @param $ the storage state of LendingStrategyStorage
    /// @param state the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)
    /// @param targetDebtUSD target debt value in USD to reach
    function rebalanceDownToDebt(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 targetDebtUSD
    ) public {
        uint256 collateralPriceUSD =
            $.oracle.getAssetPrice(address($.assets.collateral));

        uint8 collateralDecimals =
            IERC20Metadata(address($.assets.collateral)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.collateral, $.assets.debt);

        uint256 remainingDebtUSD = state.debtUSD - targetDebtUSD;
        uint256 count;

        do {
            uint256 collateralAmountAsset = calculateCollateralAsset(
                state,
                remainingDebtUSD * ONE_USD / (ONE_USD - offsetFactor),
                collateralPriceUSD,
                collateralDecimals
            );

            if (collateralAmountAsset == 0) {
                break;
            }

            uint256 borrowAmountAsset =
                withdrawAndSwapCollateral($, collateralAmountAsset);

            if (borrowAmountAsset == 0) {
                break;
            }

            // repay debt to AaveV3 _pool
            state =
                LoanLogic.repay($.lendingPool, $.assets.debt, borrowAmountAsset);

            remainingDebtUSD = state.debtUSD > targetDebtUSD
                ? state.debtUSD - targetDebtUSD
                : 0;

            if (++count > $.maxIterations) {
                break;
            }
        } while (targetDebtUSD < state.debtUSD);
    }

    /// @notice helper function to calculate collateral ratio
    /// @param _collateralUSD collateral value in USD
    /// @param _debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function collateralRatioUSD(uint256 _collateralUSD, uint256 _debtUSD)
        internal
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
    ) internal pure returns (uint256 usdAmount) {
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
    ) internal pure returns (uint256 assetAmount) {
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
        internal
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

        return convertUSDToAsset(
            collateralAmountUSD, collateralPriceUSD, collateralDecimals
        );
    }

    /// @notice withrdraws an amount of collateral asset and exchanges it for an
    /// amount of debt asset
    /// @param $ the storage state of LendingStrategyStorage
    /// @param collateralAmountAsset amount of collateral asset to withdraw and swap
    /// @return borrowAmountAsset amount of borrow asset received from swap
    function withdrawAndSwapCollateral(
        Storage.Layout storage $,
        uint256 collateralAmountAsset
    ) internal returns (uint256 borrowAmountAsset) {
        // withdraw collateral tokens from Aave _pool
        LoanLogic.withdraw(
            $.lendingPool, $.assets.collateral, collateralAmountAsset
        );

        // approve swapper contract to swap asset
        $.assets.collateral.approve(address($.swapper), collateralAmountAsset);

        // exchange collateralAmount of collateral tokens for borrow tokens
        return $.swapper.swap(
            $.assets.collateral,
            $.assets.debt,
            collateralAmountAsset,
            payable(address(this))
        );
    }
}
