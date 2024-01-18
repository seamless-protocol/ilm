# WrappedCbETH
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/tokens/WrappedCbETH.sol)

**Inherits:**
[IWrappedERC20PermissionedDeposit](/src/interfaces/IWrappedERC20PermissionedDeposit.sol/interface.IWrappedERC20PermissionedDeposit.md), ERC20, Ownable2Step

contract used to wrap underlying ERC20 token and mints the same amount of a wrapped token.

this contract will be used to mainly to wrap cbETH and use it as a collateral in the lending pool

but only strategies contracts will be able to get wrapped token it and borrow against it.


## State Variables
### underlying
address of the underlying token which is wrapped


```solidity
IERC20 public immutable underlying;
```


### depositor
map shows if address has pemission to wrap tokens


```solidity
mapping(address => bool) public depositor;
```


## Functions
### onlyDepositors


```solidity
modifier onlyDepositors();
```

### constructor


```solidity
constructor(
    string memory _name,
    string memory _symbol,
    IERC20 _underlyingToken,
    address _initialOwner
) ERC20(_name, _symbol) Ownable(_initialOwner);
```

### deposit

deposits underlying tokens and mint the same amount of wrapped tokens

*only permissioned depositors are allowed to deposit*


```solidity
function deposit(uint256 amount) external override onlyDepositors;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|amount of the tokens to wrap, in wei|


### withdraw

burns amount of wrapped tokens and recieves back the underlying token


```solidity
function withdraw(uint256 amount) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|amount of the tokens to withdraw, in wei|


### setDepositPermission

gives or withdraws permission to deposit


```solidity
function setDepositPermission(address account, bool toSet)
    external
    override
    onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|account address to give/withdraw permission|
|`toSet`|`bool`|flag set to true to give permission, or false to withdraw permission|


### recover

function used to recover underlying tokens sent directly to this contract by mistake


```solidity
function recover() external override onlyOwner;
```

