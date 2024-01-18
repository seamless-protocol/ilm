# Integrated Liquidity Markets (ILM)

The ILMs are a set of contracts which increase capital efficiency chiefly by reducing friction of capital deployment and costs of position management.

## Looping Strategy

### Overview
The `LoopingStrategy` is the first of a set of strategy contracts which will comprise the `Integrated Liquidity Markets` (ILMs). It recursively supplies deposited assets as collateral and takes out loans against that collateral to multiplicatively increase the exposure to the asset provided as collateral - hence the name `Looping`.

![Looping Strategy](https://953119082-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FUh7w5UXhBr7jGvg6R4FO%2Fuploads%2FFETfVcCSMps0WsWEALkC%2FILM%20diagram.png?alt=media&token=855a0dc2-ac65-47bd-b966-19622a324353 "Looping strategy")

In a nutshell, the "loop" goes as follows:
- User collateral is pooled and deposited into the lending pool as a single position
- Debt assets are borrowed from the pool against the supplied collateral
- Debt assets are exchanged on an external DEX for the collateral asset
- The additiona collateral asset is supplied back to the lending pool
- Strategy is enabled to borrow more debt assets

To manage the loans, the `LoopingStrategy` contracts leverage the OpenZeppelin Defender platform in order to supply more, or repay part of the loans, in order to keep the position within an acceptable risk margin. Specifically the LoopStrategy contract automatically rebalances on significant deposits, withdrawals, and changes in the price of collateral or debt assets.

The `LoopingStrategy` overrides the `ERC4626` standard to mint/burn user shares, and integrates with the `Seamless` protocol for borrowing. As a result all debt is attributed to the strategy, and the strategy holds `sTokens` or `debtTokens`, with the positions of users in the strategy are directly reflected by their shares.

Below some key concepts, and their implementations, integral to the functioning of the `LoopStrategy` are expanded upon.

### Rebalancing

The strategy adjusts risk by maintaining a desired (target) collateral ratio, defined as the ratio of collateral asset and debt asset in USD value. As the price of collateral asset increases, so does the value of the collateral. To maintain the target collateral ratio, the strategy borrows more from the lending pool, exchanges it for the collateral asset and supplies it back to the lending pool. This increases exposure to the collateral asset, subsequently increasing the equity of share tokens. 

Rebalance margins have been implemented allow for small deviations from the target collateral ratio in order to minimize the frequency of rebalances, mitigating equity loss caused by DEX fees upon swapping. Additionally, a second, smaller margin has been implemented around the target to accommodate small deposit/withdrawal actions (relative to the total TVL), preventing unnecessary rebalances and further preventing the burdening of users with DEX fees.

### Deposit

Users can deposit any amount of collateral assets into the `LoopStrategy`. In return, users receive share tokens (ERC20) representing their position in the strategy. These share tokens are transferable, along with any rights to the assets they represent - both their respective debt, and collateral, get transferred as well. 

### Redeem

By burning share tokens, users receive a proportional amount of collateral back, after paying back the debt corresponding to the shares. Users are allowed to redeem share tokens at any time.

### Fees

The strategy contract itself does not impose any fees. However the strategy, and subsequently the users, incur DEX fees during the swapping of debt assets for collateral assets (resulting in a lower equity of the strategy), as well as accruing debt interest on the borrowed asset.

### Abbreviations and Formulas

- Collateral value: `CV = value of total collateral in USD`
- Borrow Value: `BV = value of total debt in USD`
- Pool Equity: `EV = CV - BV`
- Collateral Ratio: `CR = CV / BV`
- Total shares: `TS = Total number of shares`
- Share value: `SV = EV / TS`
- `totalAssets()` from ERC4626 is overridden to return Pool Equity value

## Contracts

Natspec-generated documentation can be found [here](/docs/src/SUMMARY.md).

### LoopStrategy

`LoopStrategy`` is the user-facing contract that inherits the ERC4626 standard. It holds the lending pool tokens (sTokens/debtTokens) and manages its position using helper libraries. It features deposit/redeem functions as well as configuration functions.

The `mint` and `withdraw` functions from ERC4626 are disabled due to the complexity of share calculation. Instead, the `deposit` and `redeem` functions are overridden and act as the primary mechanisms for entry and exit into the strategy, respectively.

#### Deposit Algorithm

1. If the current collateral ratio is outside the defined margin, the pool rebalances.
2. The totalAssets (pool equity before user deposit) are then recorded as `prevTAssets`.
3. The collateral ratio is recorded as `prevCR`.
4. The collateral assets are deposited into the Seamless lending pool.
5. The resulting collateral ratio is recorded as `afterCR`.
6. If `afterCR` is below the `maxForDepositRebalance` margin, no rebalance is needed; otherwise, the pool rebalances to the collateral ratio given by `max(prevCR, targetCR)`.
7. The totalAssets after rebalanceUp (pool equity after user deposit) are recorded as `afterTAssets`. Users effectively added `userAssets = (afterTAssets - prevTAssets)` of equity.
8. The number of shares that the user gets is calculated based on `userAssets` and `totalShares`, as per the ERC4646 specification:
   - `shares = (userAssets * totalShares + 1) / (totalAssets + 1)`

Important note: if there is insufficient borrowing liquidity for the rebalance operation, the deposit is still allowed; user funds are held until rebalancing is possible again. This may result in the collateral ratio being above the target and potentially above the rebalancing margin range, and rebalancing will resume once borrowing liquidity becomes available.

#### Redeem Algorithm

1. If the current collateral ratio is outside the defined margin, the pool rebalances.
2. Users redeem `W` shares.
3. Users also specify `minAmountOut` of the underlying asset they expect. This is to safeguard against DEX price changes between transaction submission and execution which may resul in a less than expected withdrawal.
4. The current collateral ratio is saved as `prevCR`.
5. The DOLLAR value of shares (`vUA`) is converted to the amount of the underlying asset (`UA`).
6. If, after the withdrawal of `UA` from the lending pool, the collateral ratio is above `minForWithdrawRebalance` margin, collateral assets are withdrawn directly to the user address without DEX swaps and rebalances.
7. Otherwise, if the withdrawal of collateral resulted in a collateral ratio below `minForWithdrawRebalance` margin, the pool rebalances to the collateral ratio given by `min(prevCR, targetCR)`.
8. During the rebalance, the user redeeming the shares is burdened with the associated DEX fees, so that the pool does not incur these costs as lost equity.

   - Total collateral withdrawal value: `TCW`
   - Total collateral exchanged for borrowing asset: `TCE`
   - Total borrowing asset obtained after the exchange: `TBE`
   - User’s share value (`vUA`) is equal to `vUA = TCW - TBE`
   - The amount that the user gets back (withdrawal: `W`) is calculated as `W = TCW - TCE`

9. If the amount that the user gets is less than the specified `minAmountOut`, the transaction is reverted.

### LoanLogic

The LoanLogic library contains all the logic required for interacting with the Seamless lending pool. It includes helper functions to retrieve the current state of the loan, and, crucially, a function to calculate the maximum amount of possible borrowings and withdrawals of supplied collateral.

### RebalanceLogic

The RebalanceLogic library contains all the logic for all the rebalancing operations the strategy undergoes.

#### Rebalance Algorithm

- When the collateral ratio is above the `maxForRebalance`:

  1. Calculate amount of debt asset which needs to be borrowed to reach the target collateral ratio.
  2. Borrow debt assets from the lending pool. If there is not enough debt asset to borrow, borrow as much as possible.
  3. Swap debt assets for collateral assets via the DEX.
  4. Supply collateral assets as collateral to the lending pool.
  5. Repeat the process until the collateral ratio is still below the `maxForRebalance` ratio.

- When the collateral ratio is below the `minForRebalance`:

  1. Caculate amount of collateral asset needs to be withdrawn from the pool to reach the target collateral ratio.
  2. Withdraw collateral assets and swap them for debt assets via the DEX.
  3. Repay debt with the debt asset.
  4. Repeat the process until the collateral ratio is above the minimum collateral ratio.

### USDWadRayMath

The USDWadRayMath library contains helper functions for the multiplication and division of numbers with 8, 18, and 27 decimals.

## Swapper

The Swapper contract is used by the strategy as a router for DEXs. It defines a unique route to swap from the starting asset to the destination asset, allowing the use of multiple DEXs on the route. An `offset factor` is defined for each route to estimate the total amount lost on fees and potential slippage, represented as a percentage.

## WrappedCbETH

The Wrapped CbETH token is a wrapped version of CbETH, allowing the token to be distinguished from the standard CbETH token in the lending pool. This distinction enables the setting of different risk parameters. Only the strategy (and swapper) is permitted to wrap and supply this token to the lending pool.
