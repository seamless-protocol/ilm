# CollateralRatio
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/types/DataTypes.sol)

Contains all structs used in the Integrated Liquidity Market contract suite

*contains all data relating to the collateral ratio*


```solidity
struct CollateralRatio {
    uint256 target;
    uint256 minForRebalance;
    uint256 maxForRebalance;
    uint256 minForWithdrawRebalance;
    uint256 maxForDepositRebalance;
}
```

