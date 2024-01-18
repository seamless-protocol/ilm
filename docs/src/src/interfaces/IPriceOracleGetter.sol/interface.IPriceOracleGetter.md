# IPriceOracleGetter
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/IPriceOracleGetter.sol)

**Author:**
Aave

Interface for the Aave price oracle.


## Functions
### BASE_CURRENCY

Returns the base currency address

*Address 0x0 is reserved for USD as base currency.*


```solidity
function BASE_CURRENCY() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Returns the base currency address.|


### BASE_CURRENCY_UNIT

Returns the base currency unit

*1 ether for ETH, 1e8 for USD.*


```solidity
function BASE_CURRENCY_UNIT() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Returns the base currency unit.|


### getAssetPrice

Returns the asset price in the base currency


```solidity
function getAssetPrice(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The price of the asset|


