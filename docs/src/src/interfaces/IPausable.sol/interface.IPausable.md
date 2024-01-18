# IPausable
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/interfaces/IPausable.sol)

interface for Pausable functionality


## Functions
### pause

set paused state to true


```solidity
function pause() external;
```

### unpause

set paused state to false


```solidity
function unpause() external view;
```

### paused

returns paused state


```solidity
function paused() external view returns (bool state);
```

## Errors
### EnforcedPause
the operation failed because the contract is paused


```solidity
error EnforcedPause();
```

