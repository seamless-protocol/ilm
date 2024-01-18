// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { LoanLogic } from "./LoanLogic.sol";
import { ConversionMath } from "./math/ConversionMath.sol";
import { RebalanceMath } from "./math/RebalanceMath.sol";
import { USDWadRayMath } from "./math/USDWadRayMath.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
import { LoopStrategyStorage as Storage } from
    "../storage/LoopStrategyStorage.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../types/DataTypes.sol";

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
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        state = LoanLogic.supply($.lendingPool, $.assets.collateral, assets);

        uint256 afterCollateralRatio =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (prevCollateralRatio == type(uint256).max) {
            rebalanceTo($, state, $.collateralRatioTargets.target);
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

            rebalanceTo($, state, rebalanceToRatio);
        }
    }

    /// @notice performs a rebalance operation before withdrawing an equity asset amount from the lending pool,
    /// during a redemption of shares
    /// @param $ the storage state of LendingStrategyStorage
    /// @param shares amount of shares to redeem
    /// @param totalShares total supply of shares
    /// @return shareEquityAsset amount of equity in asset corresponding to shares
    function rebalanceBeforeWithdraw(
        Storage.Layout storage $,
        uint256 shares,
        uint256 totalShares
    ) external returns (uint256 shareEquityAsset) {
        // get updated loan state
        LoanState memory state = updateState($);

        // calculate amount of debt and equity corresponding to shares in USD value
        (uint256 shareDebtUSD, uint256 shareEquityUSD) =
            LoanLogic.shareDebtAndEquity(state, shares, totalShares);

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
            RebalanceMath.collateralRatioUSD(
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
        shareEquityAsset = ConversionMath.convertUSDToAsset(
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
    /// @param targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceTo(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 targetCR
    ) public returns (uint256 ratio) {
        // current collateral ratio
        ratio =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (ratio > targetCR) {
            return rebalanceUp($, state, ratio, targetCR);
        } else {
            return rebalanceDown($, state, ratio, targetCR);
        }
    }

    /// @notice performs a rebalance if necessary and returns the updated state after
    /// the potential rebalance
    /// @param $ Storage.Layout struct
    /// @return state current LoanState of strategy
    function updateState(Storage.Layout storage $)
        public
        returns (LoanState memory state)
    {
        // get current loan state and calculate initial collateral ratio
        state = LoanLogic.getLoanState($.lendingPool);
        uint256 collateralRatio =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        // if collateralRatio is outside range, user should not incur rebalance costs
        if (
            collateralRatio != type(uint256).max
                && rebalanceNeeded(collateralRatio, $.collateralRatioTargets)
        ) {
            rebalanceTo($, state, $.collateralRatioTargets.target);

            state = LoanLogic.getLoanState($.lendingPool);
        }
    }

    /// @notice mimics the operations required to supply an asset to the lending pool, estimating
    /// the overall equity added to the strategy in terms of underlying asset (1e18)
    /// @param $ Storage.Layout struct
    /// @param assets amount of collateral asset to be supplied
    /// @return suppliedEquityAsset esimated amount of equity supplied in asset terms (1e18)
    function estimateSupply(Storage.Layout storage $, uint256 assets)
        external
        view
        returns (uint256 suppliedEquityAsset)
    {
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);
        uint256 estimateTargetCR;

        uint256 underlyingPriceUSD =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 underlyingDecimals =
            IERC20Metadata(address($.assets.underlying)).decimals();

        uint256 assetsUSD = ConversionMath.convertAssetToUSD(
            assets,
            underlyingPriceUSD,
            IERC20Metadata(address($.assets.underlying)).decimals()
        );

        if (currentCR == type(uint256).max) {
            estimateTargetCR = $.collateralRatioTargets.target;
        } else {
            if (rebalanceNeeded(currentCR, $.collateralRatioTargets)) {
                currentCR = $.collateralRatioTargets.target;
            }

            uint256 afterCR = RebalanceMath.collateralRatioUSD(
                state.collateralUSD + assetsUSD, state.debtUSD
            );
            if (afterCR > $.collateralRatioTargets.maxForDepositRebalance) {
                estimateTargetCR = currentCR;
                if (
                    $.collateralRatioTargets.maxForDepositRebalance
                        > estimateTargetCR
                ) {
                    estimateTargetCR =
                        $.collateralRatioTargets.maxForDepositRebalance;
                }
            } else {
                estimateTargetCR = afterCR;
            }
        }

        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.collateral, $.assets.debt);
        uint256 borrowAmountUSD = RebalanceMath.requiredBorrowUSD(
            estimateTargetCR, assetsUSD, 0, offsetFactor
        );
        uint256 collateralAfterUSD = borrowAmountUSD.usdMul(estimateTargetCR);
        uint256 estimatedEquityUSD = collateralAfterUSD - borrowAmountUSD;

        return ConversionMath.convertUSDToAsset(
            estimatedEquityUSD, underlyingPriceUSD, underlyingDecimals
        );
    }

    /// @notice mimics the operations required to withdraw an asset from the lending pool, estimating
    /// the overall equity received from the strategy in terms of underlying asset (1e18)
    /// @param $ Storage.Layout struct
    /// @param shares amount of shares to burn to receive equity
    /// @param totalShares total supply of shares
    /// @return shareEquityAsset amount of equity assets received for the burnt shares
    function estimateWithdraw(
        Storage.Layout storage $,
        uint256 shares,
        uint256 totalShares
    ) external view returns (uint256 shareEquityAsset) {
        // get current loan state and calculate initial collateral ratio
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 collateralRatio =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        // if collateralRatio is outside range, user should not incur rebalance costs
        if (
            collateralRatio != type(uint256).max
                && rebalanceNeeded(collateralRatio, $.collateralRatioTargets)
        ) {
            // calculate amount of collateral needed to bring the collateral ratio
            // to target
            uint256 neededCollateralUSD = RebalanceMath.requiredCollateralUSD(
                $.collateralRatioTargets.target,
                state.collateralUSD,
                state.debtUSD,
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );

            // calculate new debt and collateral values after collateral has been exchanged
            // for rebalance
            state.collateralUSD -= neededCollateralUSD;
            state.debtUSD -= RebalanceMath.offsetUSDAmountDown(
                neededCollateralUSD,
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );
        }

        // calculate amount of debt and equity corresponding to shares in USD value
        (uint256 shareDebtUSD, uint256 shareEquityUSD) =
            LoanLogic.shareDebtAndEquity(state, shares, totalShares);

        // case when redeemer is redeeming all remaining shares
        if (state.debtUSD == shareDebtUSD) {
            uint256 collateralNeededUSD = shareDebtUSD.usdDiv(
                USDWadRayMath.USD
                    - $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );

            shareEquityUSD -= collateralNeededUSD.usdMul(
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );
        } else if (
            RebalanceMath.collateralRatioUSD(
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

            // amount of collateral needed for repaying debt of shares after
            // freeEquityUSD is accounted for
            uint256 neededCollateralUSD = shareDebtUSD.usdDiv(
                USDWadRayMath.USD
                    - $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );

            shareEquityUSD -= neededCollateralUSD.usdMul(
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );
        }

        shareEquityAsset = ConversionMath.convertUSDToAsset(
            shareEquityUSD,
            $.oracle.getAssetPrice(address($.assets.underlying)),
            IERC20Metadata(address($.assets.underlying)).decimals()
        );

        return shareEquityAsset;
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
    ) internal returns (uint256 ratio) {
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
                uint256 neededBorrowUSD = RebalanceMath.requiredBorrowUSD(
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
            uint256 borrowAmountAsset = ConversionMath.convertUSDToAsset(
                borrowAmountUSD, debtPriceUSD, debtDecimals
            );

            if (borrowAmountAsset == 0) {
                break;
            }

            // borrow _assets from lending _pool
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

            // collateralize _assets in lending _pool
            _state = LoanLogic.supply(
                $.lendingPool, $.assets.collateral, collateralAmountAsset
            );

            // update collateral ratio value
            ratio = RebalanceMath.collateralRatioUSD(
                _state.collateralUSD, _state.debtUSD
            );

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
    /// @param currentCR current value of collateral ratio
    /// @param targetCR target value of collateral ratio to reach
    /// @return ratio value of collateral ratio after rebalance
    function rebalanceDown(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 currentCR,
        uint256 targetCR
    ) internal returns (uint256 ratio) {
        uint256 collateralPriceUSD =
            $.oracle.getAssetPrice(address($.assets.collateral));

        uint8 collateralDecimals =
            IERC20Metadata(address($.assets.collateral)).decimals();

        // get offset caused by DEX fees + slippage
        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.collateral, $.assets.debt);

        uint256 margin = targetCR * $.ratioMargin / ONE_USD;
        uint256 count;

        do {
            // current collateral ratio
            ratio = currentCR;

            uint256 collateralAmountAsset = RebalanceMath
                .calculateCollateralAsset(
                state,
                RebalanceMath.requiredCollateralUSD(
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

            // repay debt to lending _pool
            state =
                LoanLogic.repay($.lendingPool, $.assets.debt, borrowAmountAsset);

            // update collateral ratio value
            ratio = RebalanceMath.collateralRatioUSD(
                state.collateralUSD, state.debtUSD
            );

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
    ) internal {
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
            uint256 collateralAmountAsset = RebalanceMath
                .calculateCollateralAsset(
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

            // repay debt to lending _pool
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

    /// @notice withrdraws an amount of collateral asset and exchanges it for an
    /// amount of debt asset
    /// @param $ the storage state of LendingStrategyStorage
    /// @param collateralAmountAsset amount of collateral asset to withdraw and swap
    /// @return borrowAmountAsset amount of borrow asset received from swap
    function withdrawAndSwapCollateral(
        Storage.Layout storage $,
        uint256 collateralAmountAsset
    ) internal returns (uint256 borrowAmountAsset) {
        // withdraw collateral tokens from lending _pool
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

    /// @dev returns if collateral ratio is out of the acceptable range and reabalance should happen
    /// @param collateralRatio given collateral ratio
    /// @param collateraRatioTargets struct which contain targets (min and max for rebalance)
    function rebalanceNeeded(
        uint256 collateralRatio,
        CollateralRatio memory collateraRatioTargets
    ) internal pure returns (bool) {
        return (
            collateralRatio < collateraRatioTargets.minForRebalance
                || collateralRatio > collateraRatioTargets.maxForRebalance
        );
    }
}
