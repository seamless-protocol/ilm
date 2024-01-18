# ISwapper
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/ISwapper.sol)

interface for Swapper contract

*Swapper contract functions as registry and router for Swapper Adapters*


## Functions
### getRoute

returns the steps of a swap route


```solidity
function getRoute(address from, address to)
    external
    returns (Step[] memory steps);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|address of token to swap from|
|`to`|`address`|address of token to swap to|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`steps`|`Step[]`|array of swap steps needed to end up with `to` token from `from` token|


### setRoute

sets the a steps of a swap route


```solidity
function setRoute(address from, address to, Step[] calldata steps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|address of token to swap from|
|`to`|`address`|address of token to swap to|
|`steps`|`Step[]`| array of swap steps needed to end up with `to` token from `from` token|


### swap

swaps a given amount of a token to another token, sending the final amount to the beneficiary


```solidity
function swap(
    IERC20 from,
    IERC20 to,
    uint256 fromAmount,
    address payable beneficiary
) external returns (uint256 toAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`IERC20`|address of token to swap from|
|`to`|`IERC20`|address of token to swap to|
|`fromAmount`|`uint256`|amount of from token to swap|
|`beneficiary`|`address payable`|receiver of final to token amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`toAmount`|`uint256`|amount of to token returned from swapping|


### offsetFactor

calculates the offset factor for the entire swap route from `from` token to `to` token


```solidity
function offsetFactor(IERC20 from, IERC20 to)
    external
    view
    returns (uint256 offset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`IERC20`|address of `from` token|
|`to`|`IERC20`|address of `to` token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`offset`|`uint256`|factor between 0 - 1e18 to represent offset (1e18 is 100% offset so 0 value returned)|


## Structs
### Step
*struc to encapsulate a single swap step for a given swap route*


```solidity
struct Step {
    IERC20 from;
    IERC20 to;
    ISwapAdapter adapter;
}
```

