# LoanState
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/types/DataTypes.sol)

*contains all data pertaining to the current position state of the strategy*


```solidity
struct LoanState {
    uint256 collateralUSD;
    uint256 debtUSD;
    uint256 maxWithdrawAmount;
}
```

