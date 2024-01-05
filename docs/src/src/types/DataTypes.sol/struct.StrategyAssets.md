# StrategyAssets
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/types/DataTypes.sol)

*contains assets addresses that strategy is using*


```solidity
struct StrategyAssets {
    IERC20 underlying;
    IERC20 collateral;
    IERC20 debt;
}
```

