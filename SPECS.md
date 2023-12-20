# ILM

The LoopingStrategy is a contract that manages user positions in a protocol, integrating the ERC4626 standard and employing a Keeper for position management through rebalancing. It holds underlying tokens (aTokens/debtTokens) and is responsible for managing user positions by minting/burning share tokens. Key variables include the target collateral ratio (CR) and an acceptable collateral ratio range.

![Looping Strategy](https://953119082-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FUh7w5UXhBr7jGvg6R4FO%2Fuploads%2FFETfVcCSMps0WsWEALkC%2FILM%20diagram.png?alt=media&token=855a0dc2-ac65-47bd-b966-19622a324353 "Looping strategy").

# Contracts

## Looping Strategy

- User-facing contract inherits ERC4626
- Keeper integrated for position management via rebalancing
- Holds underlying tokens (aTokens/debtTokens)
- Responsible for managing user positions via minting/burning share tokens
- Key variables:
  - Target collateral ratio (CR)
  - Acceptable collateral ratio range
    - Min/Max collateral ratio, if the current CR is not in this range, we rebalance to the Target CR
- Swapper Suite - comprised of `Swapper` and `SwapAdapter`

  - `Swapper` - Functions as a router and registry - Above functionality provided by storing `input` and `output` (from/to) tokens to swap “routes” comprised of Steps (see interface for `Step` struct definition)
    Contains admin functions for upgrading and setting `steps` for given `from`/`to` token pairs
  - `Adapter`
    - Each adapter is paired with an `AdapterLibrary` to convert the input data from the `Swapper` to the data needed to be passed in for that particular adapters swap functions
    - The adapter contains one key functions
      - `executeSwap` - executes a swap based on input parameters (from/to tokens, amountIn, minAmountOut)

- Pricing Oracle Suite

  - For the pricing of wrapped cbETH we will use Chainlink oracle for cbETH/USD pair
  - Using existing Aave Oracles contracts (same as already used in Seamless protocol)

- Logic libraries - linked libraries to save on bytecode size

  - `RebalanceLogic`
    - Contains key value formulas/calculations (equity, collateral, collateral ratio)
    - Contains `rebalanceDown/Up` functions
    - Provides backbone for most key operations involved looping maths
  - `LendingLogic`
    - Borrow function for borrowing from lending protocol
    - Repay function for repay the lending protocol
    - Deposit function for depositing collateral to the lending protocol

- Vault Flows and Key Formulas

  - Key Formulas:
    - Collateral value: `CV = value of underlying cbETH in USD`
    - Borrow Value: `BV = value of total current debt in USD`
    - Pool Equity: `EV = CV - BV`
    - totalAssets() from ERC4626 overridden to return Pool Equity value
    - Collateral Ratio: `CR=CV/BV`
    - Total shares: `TS = Total number of shares`
    - Share value: `SV = EV/TS`

- Spreadsheet with scenarios:
  ​​ Vault share calculation models: https://docs.google.com/spreadsheets/d/1d9L_uX4qYCo6i7jxQXZjI55ogBsNhNI2q8jbdJ2P6g0

- Deposit/Redeem (and mint/withdraw) logic:

  - If collateral ratio is out of the acceptable range, we do rebalance before the deposit/redeem action
  - If collateral ratio is brought closer to the target ratio, we don’t need to do any rebalance and calling dex swaps (if CR is in the proximity to the target)

- Deposit:

  - If the pool is out of acceptable CR, we do rebalance first
  - We save current totalAssets (pool equity before user deposit) = prevTAssets
  - We save current CR -> prevCR
  - Deposit users cbETH to the aave pool
  - We see the resulting CR -> afterCR
  - If afeterCR is below maxTargetCR we don’t need to do any rebalance
  - Otherwise, it is above maxTargetCR, and in that case we rebalance to the ratio of max(prevCR, targetCR)
    - If there are no borrowing liquidity available for the rebalance, we still allow the deposit! This will bring up CR above target, and maybe even above acceptable CR range, but the pool will rebalance once borrowing liquidity becomes available
  - We see what is the change in totalAssets after rebalanceUp -> afterTAssets
    - User effectively added userAssets = (afterTAssets - prevTAssets)
  - Calculate how much shares user gets based on prevTAsets, userAssets and totalShares
    - Using \_convertToShares() from OZ erc4626

- Redeem:

  - If the pool is out of acceptable collateral ratio range, we do rebalance first
  - User redeems W shares
    - User also specifies minAmountOut of the underlying asset he expects. This is because the price on dex can change until his transaction is minted (maybe frontrunning is possible) which can result in getting less than expected withdrawal.
  - We save current CR -> prevCR
  - We convert value of shares (vUA) to the amount of underlying asset -> UA
  - If after the withdrawal of UA from aave pool, CR is above minTargetCR, we just give withdrawal to the user, without dex swaps and rebalances
  - Otherwise it is below minTargetCR, and in that case we rebalance to the ratio of min(prevCR, targetCR)
  - During the rebalance dex fees goes against the withdrawer
    - Total collateral withdrawal value: TCW
    - Total collateral exchanged to borrowing asset: TCE
    - Total borrowing asset got after exchange: TBE
    - User’s share value (vUA) is equal to vUA = TCW - TBE
    - Amount which user gets back (withdrawal: W) is: W = TCW - TCE
  - If the amount of what user gets is less than specified minAmountOut we revert transaction

- Pool rebalancing:

  - On price change of the underlying (cbETH) if the collateral ratio goes out of the [minRebalanceCR, maxRebalanceCR] range, we rebalance to the target CR
  - In this case, dex fees go against the whole pool.
  - We run the OpenZepppelin Keeper to check the same thing and do rebalancing when there are no deposits/withdrawals but the underlying token price changed

  - Rebalancing when the CR is above the maxRebalanceCR
    - Calculation of how much USDbC we should borrow to get to the target collateral ratio
    - Borrow USDbC from the pool
      - If there is not enough USDbC to borrow we borrow as much as we can
    - Buy cbETH from the dex/aggregator
    - Put cbETH back as a collateral to the pool
    - Repeat the process if we are still above the maxRebalanceCR

- Rebalancing when the CR is below the minRebalanceCR
  - Calculation of how much collateral cbETH we should withdraw from the pool
  - Withdraw cbETH and sell on dex/aggregator for USDbC
  - Repay debt with the USDbC
  - Repeat the process if we are still above maximum collateral ratio
