# ISwapAdapter
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/ISwapAdapter.sol)

interface for SwapAdapter contracts


## Functions
### executeSwap

swaps a given amount of a token to another token, sending the final amount to the beneficiary

*this is the only function that _must_ be implemented by a swap adapter - all DEX-specific logic
is contained therein*


```solidity
function executeSwap(
    address from,
    address to,
    uint256 fromAmount,
    address payable beneficiary
) external returns (uint256 toAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|address of token to swap from|
|`to`|`address`|address of token to swap to|
|`fromAmount`|`uint256`|amount of from token to swap|
|`beneficiary`|`address payable`|receiver of final to token amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`toAmount`|`uint256`|amount of to token returned from swapping|


