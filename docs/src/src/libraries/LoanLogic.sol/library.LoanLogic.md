# LoanLogic
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/libraries/LoanLogic.sol)

Contains all logic required for managing the loan position on the Seamless protocol

*when calling pool functions, `onBehalfOf` is set to `address(this)` which, in most cases,*

*represents the strategy vault contract.*


## State Variables
### MAX_AMOUNT_PERCENT
*used for availableBorrowsBase and maxWithdrawAmount to decrease them by 0.01%*

*because precision issues on converting to asset amounts can revert borrow/withdraw on lending pool*


```solidity
uint256 public constant MAX_AMOUNT_PERCENT = 9999;
```


## Functions
### supply

collateralizes an amount of the given asset via depositing assets into Seamless lending pool


```solidity
function supply(LendingPool memory lendingPool, IERC20 asset, uint256 amount)
    external
    returns (LoanState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|
|`asset`|`IERC20`|address of collateral asset|
|`amount`|`uint256`|amount of asset to collateralize|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state after supply call|


### withdraw

withdraws collateral from the lending pool


```solidity
function withdraw(LendingPool memory lendingPool, IERC20 asset, uint256 amount)
    external
    returns (LoanState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|
|`asset`|`IERC20`|address of collateral asset|
|`amount`|`uint256`|amount of asset to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state after supply call|


### borrow

borrows an amount of borrowed asset from the lending pool


```solidity
function borrow(LendingPool memory lendingPool, IERC20 asset, uint256 amount)
    external
    returns (LoanState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|
|`asset`|`IERC20`|address of borrowing asset|
|`amount`|`uint256`|amount of asset to borrow|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state after supply call|


### repay

repays an amount of borrowed asset to the lending pool


```solidity
function repay(LendingPool memory lendingPool, IERC20 asset, uint256 amount)
    external
    returns (LoanState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|
|`asset`|`IERC20`|address of borrowing asset|
|`amount`|`uint256`|amount of borrowing asset to repay|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state after supply call|


### getLoanState

returns the current state of loan position on the Seamless Protocol lending pool for the caller's account

all returned values are in USD value


```solidity
function getLoanState(LendingPool memory lendingPool)
    internal
    view
    returns (LoanState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state after supply call|


### getAvailableAssetSupply

returns the available supply for the asset, taking into account defined borrow cap


```solidity
function getAvailableAssetSupply(LendingPool memory lendingPool, IERC20 asset)
    internal
    view
    returns (uint256 availableAssetSupply);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|
|`asset`|`IERC20`|asset for which the available supply is returned|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`availableAssetSupply`|`uint256`|available supply|


### _getTotalBorrow

returns the total amount of borrow for given asset reserve data


```solidity
function _getTotalBorrow(DataTypes.ReserveData memory reserveData)
    internal
    view
    returns (uint256 totalBorrow);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reserveData`|`DataTypes.ReserveData`|reserve data (external aave type) for the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalBorrow`|`uint256`|total borrowed amount|


### getMaxBorrowUSD

returns the maximum borrow avialble for the asset in USD terms, taking into account borrow cap and asset supply


```solidity
function getMaxBorrowUSD(
    LendingPool memory lendingPool,
    IERC20 debtAsset,
    uint256 debtAssetPrice
) internal view returns (uint256 maxBorrowUSD);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingPool`|`LendingPool`|struct which contains lending pool setup (pool address and interest rate mode)|
|`debtAsset`|`IERC20`|asset for wich max borrow is returned|
|`debtAssetPrice`|`uint256`|price of the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`maxBorrowUSD`|`uint256`|maximum available borrow|


