# ILM

The Looping Strategy is a set of contracts that manages user positions in a protocol, integrating the ERC4626 standard and employing OpenZeppelin Defender platform for automatization of position management through rebalancing. It holds underlying lending pool tokens (sTokens/debtTokens) and is responsible for managing user positions by minting/burning share tokens.

Users are allowed to deposit and withdraw collateral at any moment. Their collateral will be pooled, and deposited to the lending pool as a single position. Debt asset is borrowed from the pool against the suplied collateral, which is then exchanged on the external DEX for the collateral asset, giving us more of collateral asset than we started with, which is supplied back to the lending pool, giving the strategy power to borrow even more - thus called the looping strategy by repeating this process multiple times.
LoopStrategy contract automatically rebalance on big deposits, withdrawals and changing of price of collateral or debt asset.

![Looping Strategy](https://953119082-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FUh7w5UXhBr7jGvg6R4FO%2Fuploads%2FFETfVcCSMps0WsWEALkC%2FILM%20diagram.png?alt=media&token=855a0dc2-ac65-47bd-b966-19622a324353 "Looping strategy").

## Deposit

User can deposit any amount of collateral asset to the LoopStrategy contract. In return user gets the share tokens (ERC20) which represents their position in the strategy. Share tokens are transferable, but with transferring them, also permission to redeem collateral asset is transferred

## Strategy rebalancing

Strategy will strive to keep the target collateral ratio (ratio of collateral asset and debt asset). That means as price of collateral eventually increases, strategy will borrow more from the lending pool, swapping again for the collateral asset and supplying back. Therefore, exposure to the collateral asset will increase, and the equity of share tokens would increase in that case.
Rebalance margins allow for small deviation of the target, and are defined for the reason to not do too many rebalances which occurs DEX fees. Also, additional smaller margin around target is defined to allow for small deposit/withdrawal (regarding the total TVL) which will not cause rebalance thus saving user of DEX fees.

## Redeem / Withdraw

By burning share tokens, user is getting proportional amount of collateral back. Users are allowed to redeem share tokens at any moment.

## Fees

There are no fees imposed by the strategy contract itself, but users needs to be aware of the DEX fees which occurs when the debt asset is swapped for the collateral asset (thus lowering equity of the strategy), and accruing debt interest on the borrowed asset.

# Abbreviations and Formulas

- Collateral value: `CV = value of underlying cbETH in USD`
- Borrow Value: `BV = value of total current debt in USD`
- Pool Equity: `EV = CV - BV`
- totalAssets() from ERC4626 overridden to return Pool Equity value
- Collateral Ratio: `CR = CV / BV`
- Total shares: `TS = Total number of shares`
- Share value: `SV = EV / TS`

# Contracts

Natspec generated documentation can be found [here](/docs/src/SUMMARY.md).

## LoopStrategy

LoopStrategy is the user facing contract which inherits ERC4626 standard. It holds the lending pool tokens (sTokens/debtTokens) and manages position utilizing helping libraries. It has deposit/redeem functions as well as configuration functions.

`mint` and `withdraw` function from the ERC4626 are disabled because of the complexity of share calculation, `deposit` and `redeem` functions are overridden and expected to be used.

In the `deposit` function users can use additional parameter `minSharesReceived` securing minimum amount of shares to be received. Similarly, in the `redeem` function there is additional parameter `minUnderlyingAsset` securing minimum amount of underlying asset to be redeemed.

### Deposit algorithm

1. If the pool is out of collateral ratio margin, first rebalance is done
1. totalAssets (pool equity before user deposit) is saved -> prevTAssets
1. Current collateral ratio is saved -> prevCR
1. Deposit users collateral asset to the Seamless lending pool
1. Resulting collateral ratio is saved -> afterCR
1. If afeterCR is below maxForDepositRebalance margin, rebalance is not needed
1. Otherwise, it is above maxForDepositRebalance maring, and in that case rebalancing is done to the ratio of max(prevCR, targetCR)

   - If there are no borrowing liquidity available for the rebalance, deposit is still allowed. This will bring up collateral ratio above target, and maybe even above rebalancing margin range, but the pool will rebalance once borrowing liquidity becomes available.

1. totalAssets after rebalanceUp (pool equity after user deposit) is saved -> afterTAssets

   - User effectively added userAssets = (afterTAssets - prevTAssets)

1. Number of shares which user gets is calculated based on userAssets and totalShares
   - `shares = (userAssets * totalShares + 1) / (totalAssets + 1)`

### Redeem algorithm

1. If the pool is out of collateral ratio margin, first rebalance is done
1. User redeems W shares

   - User also specifies minAmountOut of the underlying asset he expects. This is because the price on dex can change until his transaction is minted (maybe frontrunning is possible) which can result in getting less than expected withdrawal.

1. Current collateral ratio is saved -> prevCR
1. Value of shares (vUA) is converted to the amount of underlying asset -> UA
1. If after the withdrawal of UA from the lending pool, collateral ratio is above minForWithdrawRebalance margin, collateral asset is withdrawn directly to the user address, without dex swaps and rebalances
1. Otherwise it is below minForWithdrawRebalance margin, and in that case rebalance is done to the ratio of min(prevCR, targetCR)
1. During the rebalance DEX fees goes against the withdrawer

   - Total collateral withdrawal value: TCW
   - Total collateral exchanged to borrowing asset: TCE
   - Total borrowing asset got after exchange: TBE
   - User’s share value (vUA) is equal to vUA = TCW - TBE
   - Amount which user gets back (withdrawal: W) is: W = TCW - TCE

1. If the amount of what user gets is less than specified minAmountOut transaction is reverted

### LoanLogic

LoanLogic library contains all logic required for managing the loan position on the lending pool. It also contains helper functions to see the current state of the loan and to calculate maximum amount of possible borrow and withdrawal of supplied collateral.

### RebalacingLogic

RebalancingLogic library contains all logic for rebalancing the strategy and calculating how much borrowing is needed to achive defined collateral targets.

#### Rebalance algorithm

- Rebalancing when the CR is above the maxRebalanceCR

  1. Calculation of how much debt asset we should borrow to get to the target collateral ratio
  1. Borrow debt asset from the pool

  - If there is not enough debt asset to borrow we borrow as much as we can

  1. Buy collateral asset from the DEX
  1. Supply collateral asset back as a collateral to the lending pool
  1. Repeat the process if we are still above the maxRebalanceCR

- Rebalancing when the CR is below the minRebalanceCR
  1. Calculation of how much collateral asset we should withdraw from the pool
  1. Withdraw collateral asset and sell on DEX for the debt asset
  1. Repay debt with the debt asset
  1. Repeat the process if we are still above maximum collateral ratio

### USDWadRayMath

USDWadRayMath library contains helper functions for multiplication and division of numbers with 8, 18 and 27 decimals.

## Swapper

Swapper contract is used by the strategy as a router for DEXs. It defines unique route to swap from the starting asset to the destination asset. It can use multiple different DEXs on the route if needed.
`Offset factor` is defined for each route to estimate the total amount loss on fees and potential slippage, represented as percentage.

## WrappedCbETH

Wrapped CbETH token is just a wrapped version of the CbETH which allows token to differentiate from the standard CbETH token in the lending pool, thus allowing to set different risk parameters. Only strategy (and swapper) are allowed to wrap and supply this token to the lending pool.
