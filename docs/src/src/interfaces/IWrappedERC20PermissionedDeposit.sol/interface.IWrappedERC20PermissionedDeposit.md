# IWrappedERC20PermissionedDeposit
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/IWrappedERC20PermissionedDeposit.sol)

**Inherits:**
IERC20

interface for the Wrapper of ERC20 with permissioned deposit

*Wraps the underlying ERC20 contract and mints the same amount of a wrapped token.*

*Deposits are permissioned but withdrawals are open to any address.*


## Functions
### underlying

retruns the underlying token address


```solidity
function underlying() external view returns (IERC20 underlyingToken);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingToken`|`IERC20`|underlying token|


### deposit

deposits underlying tokens and mint the same amount of wrapped tokens

*only permissioned depositors are allowed to deposit*


```solidity
function deposit(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|amount of the tokens to wrap, in wei|


### withdraw

burns amount of wrapped tokens and recieves back the underlying token


```solidity
function withdraw(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|amount of the tokens to withdraw, in wei|


### recover

function used to recover underlying tokens sent directly to this contract by mistake


```solidity
function recover() external;
```

### setDepositPermission

gives or withdraws permission to deposit


```solidity
function setDepositPermission(address account, bool toSet) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|account address to give/withdraw permission|
|`toSet`|`bool`|flag set to true to give permission, or false to withdraw permission|


## Events
### Deposit
Deposit/wrapping underlying token


```solidity
event Deposit(address account, uint256 amount);
```

### Withdraw
Withdraw/unwrapping underlying token


```solidity
event Withdraw(address account, uint256 amount);
```

### SetDepositPermission
Sets deposit permission


```solidity
event SetDepositPermission(address account, bool toSet);
```

### RecoverUnderlyingSurplus
Recovers surplus of underlying token


```solidity
event RecoverUnderlyingSurplus(address account, uint256 amountSurplus);
```

## Errors
### NotDepositor
Sender doesn't have a permission to deposit


```solidity
error NotDepositor(address sender);
```

