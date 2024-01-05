# ILoopStrategy
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/ILoopStrategy.sol)

**Inherits:**
IERC4626

interface for Integration Liquiity Market strategies

*interface similar to IERC4626, with some additional functions for health management*


## Functions
### equity

returns the amount of equity belonging to the strategy
in underlying token value


```solidity
function equity() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|equity amount|


### equityUSD

returns the amount of equity belonging to the strategy
in USD value


```solidity
function equityUSD() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|equity amount|


### debt

returns the amount of debt belonging to the strategy
in underlying value (USD)


```solidity
function debt() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|debt amount|


### collateral

returns the amount of collateral belonging to the strategy
in underlying value (USD)


```solidity
function collateral() external view returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|collateral amount|


### setCollateralRatioTargets

sets the collateral ratio targets (target ratio, min and max for rebalance,

max for deposit rebalance and min for collateral rebalance)


```solidity
function setCollateralRatioTargets(
    CollateralRatio memory collateralRatioTargets
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralRatioTargets`|`CollateralRatio`|collateral ratio targets struct|


### getCollateralRatioTargets

returns min, max and target collateral ratio values


```solidity
function getCollateralRatioTargets()
    external
    view
    returns (CollateralRatio memory ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`CollateralRatio`|struct containing min, max and target collateral ratio values|


### setInterestRateMode

sets the interest rate mode for the loan


```solidity
function setInterestRateMode(uint256 interestRateMode) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interestRateMode`|`uint256`|interest rate mode per aave enum InterestRateMode {NONE, STABLE, VARIABLE}|


### currentCollateralRatio

returns the current collateral ratio value of the strategy


```solidity
function currentCollateralRatio() external view returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|current collateral ratio value|


### rebalance

rebalances the strategy

*perofrms a downwards/upwards leverage depending on the current strategy state in order to be
within collateral ratio range*


```solidity
function rebalance() external returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|value of collateral ratio after strategy rebalances|


### rebalanceNeeded

retruns true if collateral ratio is out of the target range, and we need to rebalance pool


```solidity
function rebalanceNeeded() external view returns (bool shouldRebalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shouldRebalance`|`bool`|true if rebalance is needed|


### deposit

deposit assets to the strategy with the requirement of shares received


```solidity
function deposit(uint256 assets, address receiver, uint256 minSharesReceived)
    external
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|amount of assets to deposit|
|`receiver`|`address`|address of the receiver of share tokens|
|`minSharesReceived`|`uint256`|required minimum of shares received|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|number of received shares|


### redeem

redeems an amount of shares by burning shares from the owner, and rewarding the receiver with
the share value


```solidity
function redeem(
    uint256 shares,
    address receiver,
    address owner,
    uint256 minUnderlyingAsset
) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|amount of shares to burn|
|`receiver`|`address`|address to receive share value|
|`owner`|`address`|address of share owner|
|`minUnderlyingAsset`|`uint256`|minimum amount of underlying asset to receive|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|amount of underlying asset received|


## Errors
### MintDisabled
mint function from IERC4626 is disabled


```solidity
error MintDisabled();
```

### DepositStaticcallReverted
reverts when deposit staticcal from previewDeposit reverts


```solidity
error DepositStaticcallReverted();
```

### RebalanceNotNeeded
reverts when rebalance function is called but collateral ratio is in the target range


```solidity
error RebalanceNotNeeded();
```

### SharesReceivedBelowMinimum
reverts when shares received by user on deposit is lower than given minimum


```solidity
error SharesReceivedBelowMinimum(
    uint256 sharesReceived, uint256 minSharesReceived
);
```

### UnderlyingReceivedBelowMinimum
thrown when underlying received upon share redemption or asset withdrawing is
less than given minimum limit


```solidity
error UnderlyingReceivedBelowMinimum(
    uint256 underlyingReceived, uint256 minUnderlyingReceived
);
```

### RedeemerNotOwner
thrown when the caller of the redeem function is not the owner of the
shares to be redeemed


```solidity
error RedeemerNotOwner();
```

