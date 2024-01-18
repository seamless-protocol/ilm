# LoopStrategyStorage
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/storage/LoopStrategyStorage.sol)


## State Variables
### STORAGE_SLOT

```solidity
bytes32 internal constant STORAGE_SLOT =
    0x324C4071AA3926AF75895CE4C01A62A23C8476ED82CD28BA23ABB8C0F6634B00;
```


## Functions
### layout


```solidity
function layout() internal pure returns (Layout storage l);
```

## Structs
### Layout
*struct containing all state for the LoopStrategy contract*


```solidity
struct Layout {
    StrategyAssets assets;
    CollateralRatio collateralRatioTargets;
    uint256 ratioMargin;
    uint256 usdMargin;
    IPoolAddressesProvider poolAddressProvider;
    LendingPool lendingPool;
    IPriceOracleGetter oracle;
    ISwapper swapper;
    uint16 maxIterations;
}
```

