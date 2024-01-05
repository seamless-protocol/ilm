// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20Metadata } from
    "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { USDWadRayMath } from "./math/USDWadRayMath.sol";
import { LoanLogic } from "./LoanLogic.sol";
import { RebalanceLogic } from "./RebalanceLogic.sol";
import { LoopStrategyStorage as Storage } from
    "../storage/LoopStrategyStorage.sol";
import { LoanState } from "../types/DataTypes.sol";

library ActionLogic {
    using USDWadRayMath for uint256;

    function supplyAndRebalance(
        Storage.Layout storage $,
        LoanState memory state,
        uint256 assets
    ) external {
        uint256 prevCollateralRatio = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        state = LoanLogic.supply($.lendingPool, $.assets.collateral, assets);

        uint256 afterCollateralRatio = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        if (prevCollateralRatio == type(uint256).max) {
            RebalanceLogic.rebalanceTo(
                $, state, 0, $.collateralRatioTargets.target
            );
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
           
           RebalanceLogic.rebalanceTo($, state, 0, rebalanceToRatio);
        }
    }

    function shareValueAsset(
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
            RebalanceLogic.rebalanceDownToDebt(
                $, state, state.debtUSD - shareDebtUSD
            );

            state = LoanLogic.getLoanState($.lendingPool);
            shareEquityUSD = state.collateralUSD - state.debtUSD;
        }
        //check if withdrawal would lead to a collateral below minimum acceptable level
        // if yes, rebalance until share debt is repaid, and decrease remaining share equity
        // by equity cost of rebalance
        else if (
            RebalanceLogic.collateralRatioUSD(
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
            RebalanceLogic.rebalanceDownToDebt(
                $, state, state.debtUSD - shareDebtUSD
            );

            state = LoanLogic.getLoanState($.lendingPool);

            // shares lose equity equal to the amount of equity lost for
            // the rebalance to pay the adjusted debt
            shareEquityUSD -=
                initialEquityUSD - (state.collateralUSD - state.debtUSD);
        }

        // convert equity to collateral asset
        shareEquityAsset = RebalanceLogic.convertUSDToAsset(
            shareEquityUSD,
            $.oracle.getAssetPrice(address($.assets.collateral)),
            IERC20Metadata(address($.assets.collateral)).decimals()
        );

        // withdraw and transfer equity asset amount
        LoanLogic.withdraw($.lendingPool, $.assets.collateral, shareEquityAsset);
    }
}
