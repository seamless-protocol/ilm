# Integrated Liquidity Market (ILM)
The ILMs are a set of contracts which increase capital efficiency chiefly by reducing friction of capital deployment and costs of position management. The `ILM` repo hosts all contracts, tests and deployment scripts necessary for build, test, deploy and configure the `ILM` strategies.

## Architecture
The ILMs are accessible to users by interaction with the `Strategy` contracts. The functioning of these strategies is supported by the `Swapper` contract suite, which serves the purpose of managing integrations, thus swaps, with several DEXs.

The `Strategy` contracts leverage several external libraries for borrowing/repaying loans with the `Seamless` lending pools, conversions and rebalancing. 

The `Swapper` contract is essentially a routing contract, and simply routes swaps through `SwapAdapter` contracts, which handle the DEX-specific swapping logic.

All contracts follow the unstructured storage pattern, where a hash is used to define the storage slot for the part of the state of the contract.

## Documentation
The first of these contracts is the ![Looping Strategy](./SPECS.md), which swaps borrowed funds to for collateral funds to achieve a higher exposure to the collateral token.

A ![summary](/docs/src/SUMMARY.md) of the `Looping Strategy` interfaces and contracts is provided in the repo as well.

The ILM repo is subject to the ![Styling Guide](./STYLING_GUIDE.md). 

The ILMs integrate directly with the ![Seamless Protocol](https://docs.seamlessprotocol.com/overview/introduction-to-seamless-protocol) which fulfills the role of the lender. 

## Audits
TBA

## Usage
### Installation
```forge install```

### Build
```forge build```

### Test
```forge test```

### Testnet Deployment
```forge script ./deploy/DeployTenderlyFork.s.sol --rpc-url ${TENDERLY_FORK_RPC} --broadcast --slow --delay 20 --force```

### Mainnet Deployment
TBA