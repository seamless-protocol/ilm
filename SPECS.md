# ILM (Integrated Lending Management)

The Looping Strategy comprises a set of smart contracts designed to manage user positions within a protocol. It seamlessly integrates the ERC4626 standard and leverages the OpenZeppelin Defender platform for the automation of position management through rebalancing. The strategy involves holding underlying lending pool tokens (sTokens/debtTokens) and is responsible for managing user positions through the minting and burning of share tokens.

Users have the flexibility to deposit and withdraw collateral at any given moment. Their deposited collateral is pooled and submitted to the lending pool as a single position. Debt assets are borrowed from the pool against the supplied collateral, exchanged on an external DEX for the collateral asset, resulting in an increased amount of collateral. This surplus collateral is then supplied back to the lending pool, enabling the strategy to borrow even more. This iterative process is referred to as the looping strategy, and it automatically rebalances in response to significant deposits, withdrawals, or changes in the prices of collateral or debt assets.

![Looping Strategy](https://953119082-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FUh7w5UXhBr7jGvg6R4FO%2Fuploads%2FFETfVcCSMps0WsWEALkC%2FILM%20diagram.png?alt=media&token=855a0dc2-ac65-47bd-b966-19622a324353 "Looping strategy")

## Deposit

Users can deposit any amount of collateral assets into the LoopStrategy contract. In return, users receive share tokens (ERC20) representing their positions in the strategy. While these share tokens are transferable, transferring them also involves transferring the permission to redeem collateral assets.

## Strategy Rebalancing

The strategy aims to maintain the target collateral ratio (the ratio of collateral asset to debt asset). As the price of collateral increases, the strategy borrows more from the lending pool, exchanging it for collateral assets and supplying it back. Consequently, exposure to the collateral asset increases, and the equity of share tokens also increases. Rebalance margins allow for slight deviations from the target ratio to minimize the frequency of rebalances, reducing DEX fees. An additional margin around the target ratio accommodates small deposit or withdrawal actions without triggering a rebalance, saving users from incurring unnecessary DEX fees.

## Redeem/Withdraw

By burning share tokens, users receive a proportional amount of collateral back. Users are permitted to redeem share tokens at any time.

## Fees

The strategy contract itself does not impose any fees. However, users must be aware of DEX fees incurred during the swap of debt assets for collateral assets, reducing the equity of the strategy. Additionally, users accrue debt interest on the borrowed asset.

# Abbreviations and Formulas

- Collateral value: `CV = value of underlying cbETH in USD`
- Borrow Value: `BV = value of total current debt in USD`
- Pool Equity: `EV = CV - BV`
- `totalAssets()` from ERC4626 is overridden to return Pool Equity value
- Collateral Ratio: `CR = CV / BV`
- Total shares: `TS = Total number of shares`
- Share value: `SV = EV / TS`

# Contracts

Natspec-generated documentation can be found [here](/docs/src/SUMMARY.md).

## LoopStrategy

LoopStrategy is the user-facing contract that inherits the ERC4626 standard. It holds the lending pool tokens (sTokens/debtTokens) and manages positions using helper libraries. It features deposit/redeem functions as well as configuration functions.

The `mint` and `withdraw` functions from ERC4626 are disabled due to the complexity of share calculation. Instead, the `deposit` and `redeem` functions are overridden and intended for use.

### Deposit Algorithm

1. If the pool is out of an acceptable CR, a rebalance is initiated first.
2. The current totalAssets (pool equity before user deposit) is saved as `prevTAssets`.
3. The current CR is saved as `prevCR`.
4. Users deposit cbETH into the Aave pool.
5. The resulting CR is determined (`afterCR`).
6. If `afterCR` is below `maxTargetCR`, no rebalance is needed; otherwise, a rebalance is triggered to the ratio of `max(prevCR, targetCR)`.

   - If there is insufficient borrowing liquidity for the rebalance, the deposit is still allowed, potentially bringing the CR above the target. The pool will rebalance once borrowing liquidity becomes available.

7. The change in `totalAssets` after rebalance is calculated (`afterTAssets`).

   - Users effectively added `userAssets = (afterTAssets - prevTAssets)`.

8. The number of shares users receive is calculated based on `prevTAssets`, `userAssets`, and `totalShares` using `_convertToShares()` from the OpenZeppelin ERC4626 library.

### Redeem Algorithm

1. If the pool is out of the acceptable collateral ratio range, a rebalance is initiated first.
2. Users redeem `W` shares.
3. Users specify `minAmountOut` of the underlying asset they expect due to potential price changes on the DEX.
4. The current CR is saved as `prevCR`.
5. The value of shares (`vUA`) is converted to the amount of the underlying asset (`UA`).
6. If, after the withdrawal of `UA` from the Aave pool, the CR is above `minTargetCR`, the withdrawal is granted to the user without DEX swaps and rebalances.
7. If the CR is below `minTargetCR`, a rebalance is triggered to the ratio of `min(prevCR, targetCR)`.
8. During the rebalance, DEX fees are deducted from the withdrawal.

   - Total collateral withdrawal value: `TCW`
   - Total collateral exchanged for borrowing asset: `TCE`
   - Total borrowing asset obtained after exchange: `TBE`
   - User’s share value (`vUA`) is equal to `vUA = TCW - TBE`
   - The amount the user gets back (withdrawal: `W`) is calculated as `W = TCW - TCE`

9. If the user gets less than the specified `minAmountOut`, the transaction is reverted.

### LoanLogic

The LoanLogic library contains all the logic required for managing the loan position on the lending pool. It also includes helper functions to examine the current state of the loan and calculate the maximum amount of possible borrowings and withdrawals of supplied collateral.

### RebalancingLogic

The RebalancingLogic library encompasses all the logic for rebalancing the strategy and calculating the necessary borrowing to achieve defined collateral targets.

#### Rebalance Algorithm

- Rebalancing when the CR is above the `maxRebalanceCR`:

  1. Calculate how much debt asset should be borrowed to reach the target collateral ratio.
  2. Borrow the debt asset from the pool.

  - If there is insufficient debt asset available to borrow, borrow as much as possible.

  3. Buy collateral assets from the DEX.
  4. Supply collateral assets back as collateral to the lending pool.
  5. Repeat the process if the CR is still above the `maxRebalanceCR`.

- Rebalancing when the CR is below the `minRebalanceCR`:

  1. Calculate how much collateral asset should be withdrawn from the pool.
  2. Withdraw collateral assets and sell them on the DEX for the debt asset.
  3. Repay debt with the debt asset.
  4. Repeat the process if the CR is still below the maximum collateral ratio.

### USDWadRayMath

The USDWadRayMath library contains helper functions for the multiplication and division of numbers with 8, 18, and 27 decimals.

## Swapper

The Swapper contract is used by the strategy as a router for DEXs. It defines a unique route to swap from the starting asset to the destination asset, allowing the use of multiple DEXs on the route if needed. An `offset factor` is defined for each route to estimate the total amount lost on fees and potential slippage, represented as a percentage.

## WrappedCbETH

The Wrapped CbETH token is a wrapped version of CbETH, allowing the token to be distinguished from the standard CbETH token in the lending pool. This distinction enables the setting of different risk parameters. Only the strategy (and swapper) is permitted to wrap and supply this token to the lending pool.
