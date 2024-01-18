# RebalanceLogic
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/libraries/RebalanceLogic.sol)

Contains all logic required for rebalancing


## State Variables
### ONE_USD
*ONE in USD scale and in WAD scale*


```solidity
uint256 internal constant ONE_USD = 1e8;
```


### ONE_WAD

```solidity
uint256 internal constant ONE_WAD = USDWadRayMath.WAD;
```


### USD_DECIMALS
*decimals of USD prices as per _oracle, and WAD decimals*


```solidity
uint8 internal constant USD_DECIMALS = 8;
```


### WAD_DECIMALS

```solidity
uint8 internal constant WAD_DECIMALS = 18;
```


## Functions
### rebalanceTo

performs all operations necessary to rebalance the loan state of the strategy upwards

*note that the current collateral/debt values are expected to be given in underlying value (USD)*


```solidity
function rebalanceTo(
    Storage.Layout storage $,
    LoanState memory state,
    uint256 withdrawalUSD,
    uint256 targetCR
) public returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`Storage.Layout`|the storage state of LendingStrategyStorage|
|`state`|`LoanState`|the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)|
|`withdrawalUSD`|`uint256`|amount of USD withdrawn - used to project post-collateral-withdrawal collateral ratios (useful in strategy share redemptions)|
|`targetCR`|`uint256`|target value of collateral ratio to reach|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|value of collateral ratio after rebalance|


### rebalanceUp

performs all operations necessary to rebalance the loan state of the strategy upwards

*"upwards" in this context means reducing collateral ratio, thereby _increasing_ exposure*

*note that the current collateral/debt values are expected to be given in underlying value (USD)*


```solidity
function rebalanceUp(
    Storage.Layout storage $,
    LoanState memory _state,
    uint256 _currentCR,
    uint256 _targetCR
) public returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`Storage.Layout`|the storage state of LendingStrategyStorage|
|`_state`|`LoanState`|the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)|
|`_currentCR`|`uint256`|current value of collateral ratio|
|`_targetCR`|`uint256`|target value of collateral ratio to reach|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|value of collateral ratio after rebalance|


### rebalanceDown

performs all operations necessary to rebalance the loan state of the strategy downwards

*"downards" in this context means increasing collateral ratio, thereby _decreasing_ exposure*

*note that the current collateral/debt values are expected to be given in underlying value (USD)*


```solidity
function rebalanceDown(
    Storage.Layout storage $,
    LoanState memory state,
    uint256 withdrawalUSD,
    uint256 currentCR,
    uint256 targetCR
) public returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`Storage.Layout`|the storage state of LendingStrategyStorage|
|`state`|`LoanState`|the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)|
|`withdrawalUSD`|`uint256`|amount of USD withdrawn - used to project post-collateral-withdrawal collateral ratios (useful in strategy share redemptions)|
|`currentCR`|`uint256`|current value of collateral ratio|
|`targetCR`|`uint256`|target value of collateral ratio to reach|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|value of collateral ratio after rebalance|


### rebalanceDownToDebt

rebalances downwards until a debt amount is reached


```solidity
function rebalanceDownToDebt(
    Storage.Layout storage $,
    LoanState memory state,
    uint256 targetDebtUSD
) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`Storage.Layout`|the storage state of LendingStrategyStorage|
|`state`|`LoanState`|the strategy loan state information (collateralized asset, borrowed asset, current collateral, current debt)|
|`targetDebtUSD`|`uint256`|target debt value in USD to reach|


### collateralRatioUSD

helper function to calculate collateral ratio


```solidity
function collateralRatioUSD(uint256 _collateralUSD, uint256 _debtUSD)
    public
    pure
    returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collateralUSD`|`uint256`|collateral value in USD|
|`_debtUSD`|`uint256`|debt valut in USD|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|collateral ratio value|


### convertAssetToUSD

converts a asset amount to its usd value


```solidity
function convertAssetToUSD(
    uint256 _assetAmount,
    uint256 _priceInUSD,
    uint256 _assetDecimals
) public pure returns (uint256 usdAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_assetAmount`|`uint256`|amount of asset|
|`_priceInUSD`|`uint256`|price of asset in USD|
|`_assetDecimals`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdAmount`|`uint256`|amount of USD after conversion|


### convertUSDToAsset

converts a USD amount to its token value


```solidity
function convertUSDToAsset(
    uint256 _usdAmount,
    uint256 _priceInUSD,
    uint256 _assetDecimals
) public pure returns (uint256 assetAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_usdAmount`|`uint256`|amount of USD|
|`_priceInUSD`|`uint256`|price of asset in USD|
|`_assetDecimals`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assetAmount`|`uint256`|amount of asset after conversion|


### offsetUSDAmountDown

helper function to offset amounts by a USD percentage downwards


```solidity
function offsetUSDAmountDown(uint256 _a, uint256 _offsetUSD)
    public
    pure
    returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_a`|`uint256`|amount to offset|
|`_offsetUSD`|`uint256`|offset as a number between 0 -  ONE_USD|


### requiredBorrowUSD

calculates the total required borrow amount in order to reach a target collateral ratio value


```solidity
function requiredBorrowUSD(
    uint256 targetCR,
    uint256 collateralUSD,
    uint256 debtUSD,
    uint256 offsetFactor
) public pure returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetCR`|`uint256`|target collateral ratio value|
|`collateralUSD`|`uint256`|current collateral value in USD|
|`debtUSD`|`uint256`|current debt value in USD|
|`offsetFactor`|`uint256`|expected loss to DEX fees and slippage expressed as a value from 0 - ONE_USD|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|required borrow amount|


### requiredCollateralUSD

calculates the total required collateral amount in order to reach a target collateral ratio value


```solidity
function requiredCollateralUSD(
    uint256 targetCR,
    uint256 collateralUSD,
    uint256 debtUSD,
    uint256 offsetFactor
) public pure returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetCR`|`uint256`|target collateral ratio value|
|`collateralUSD`|`uint256`|current collateral value in USD|
|`debtUSD`|`uint256`|current debt value in USD|
|`offsetFactor`|`uint256`|expected loss to DEX fees and slippage expressed as a value from 0 - ONE_USD|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|required collateral amount|


### calculateCollateralAsset

determines the collateral asset amount needed for a rebalance down cycle


```solidity
function calculateCollateralAsset(
    LoanState memory state,
    uint256 neededCollateralUSD,
    uint256 collateralPriceUSD,
    uint256 collateralDecimals
) public pure returns (uint256 collateralAmountAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state|
|`neededCollateralUSD`|`uint256`|collateral needed for overall operation in USD|
|`collateralPriceUSD`|`uint256`|price of collateral in USD|
|`collateralDecimals`|`uint256`|decimals of collateral token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateralAmountAsset`|`uint256`|amount of collateral asset needed fo the current rebalance down cycle|


### withdrawAndSwapCollateral

withrdraws an amount of collateral asset and exchanges it for an
amount of debt asset


```solidity
function withdrawAndSwapCollateral(
    Storage.Layout storage $,
    uint256 collateralAmountAsset
) public returns (uint256 borrowAmountAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`Storage.Layout`|the storage state of LendingStrategyStorage|
|`collateralAmountAsset`|`uint256`|amount of collateral asset to withdraw and swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`borrowAmountAsset`|`uint256`|amount of borrow asset received from swap|


