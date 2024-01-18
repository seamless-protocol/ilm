# IOwnable2Step
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/IOwnable2Step.sol)

**Inherits:**
IERC5313

interface to surface functions relating to Ownable2Step functionality


## Functions
### renounceOwnership

Leaves the contract without owner. It will not be possible to call
`onlyOwner` functions. Can only be called by the current owner.
NOTE: Renouncing ownership will leave the contract without an owner,
thereby disabling any functionality that is only available to the owner.


```solidity
function renounceOwnership() external;
```

### pendingOwner

Returns the address of the pending owner.


```solidity
function pendingOwner() external view returns (address nominatedOwner);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nominatedOwner`|`address`|address of owner being nominated|


### transferOwnership

Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
Can only be called by the current owner.


```solidity
function transferOwnership(address newOwner) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOwner`|`address`|address of owner being nominated as new owner|


### acceptOwnership

The new owner accepts the ownership transfer.


```solidity
function acceptOwnership() external;
```

