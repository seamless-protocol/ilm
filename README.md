# Integrated Liquidity Market (ILM)
The ILMs are a set of contracts which increase capital efficiency chiefly by reducing friction of capital deployment and costs of position management. The `ILM` repo hosts all contracts, tests and deployment scripts necessary for build, test, deploy and configure the `ILM` strategies.

## Architecture
The ILMs are accessible to users by interaction with the `Strategy` contracts. The functioning of these strategies is supported by the `Swapper` contract suite, which serves the purpose of managing integrations, thus swaps, with several DEXs.

The `Strategy` contracts leverage several external libraries for borrowing/repaying loans with the `Seamless` lending pools, conversions and rebalancing. 

The `Swapper` contract is essentially a routing contract, and simply routes swaps through `SwapAdapter` contracts, which handle the DEX-specific swapping logic.

All contracts follow the unstructured storage pattern, where a hash is used to define the storage slot for the part of the state of the contract.

## Documentation
The first of these contracts is the [Looping Strategy](./SPECS.md), which swaps borrowed funds to for collateral funds to achieve a higher exposure to the collateral token.

A [summary](/docs/src/SUMMARY.md) of the `Looping Strategy` interfaces and contracts is provided in the repo as well.

The ILM repo is subject to the [Styling Guide](./STYLING_GUIDE.md). 

The ILMs integrate directly with the [Seamless Protocol](https://docs.seamlessprotocol.com/overview/introduction-to-seamless-protocol) which fulfills the role of the lender. 

## Smart Contract addresses on Base
| Smart Contract | Address |
| --- | --- |
| wstETH/ETH 3x Loop Strategy | [0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e](https://basescan.org/address/0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e) |
| Seamless ILM Reserved wstETH | [0xc9ae3B5673341859D3aC55941D27C8Be4698C9e4](https://basescan.org/address/0xc9ae3B5673341859D3aC55941D27C8Be4698C9e4) |
| Swapper | [0xE314ae9D279919a00d4773cCe37946A98fADDaBc](https://basescan.org/address/0xE314ae9D279919a00d4773cCe37946A98fADDaBc) |
| WrappedTokenAdapter | [0xc3e17CDac7C6ED317f0D9845d47df1a281B5f79E](https://basescan.org/address/0xc3e17CDac7C6ED317f0D9845d47df1a281B5f79E) |
| AerodromeAdapter | [0x6Cfc78c96f87e522EBfDF86995609414cFB1DcB2](https://basescan.org/address/0x6Cfc78c96f87e522EBfDF86995609414cFB1DcB2) |

## Audits
TBA

## Usage
### Installation
```markdown
forge install
```

### Build
```markdown
forge build
```

### Test
```markdown
forge test
```

### Testnet Deployment
```markdown
forge script ./deploy/DeployTenderlyFork.s.sol --rpc-url ${TENDERLY_FORK_RPC} --broadcast --slow --delay 20 --force
```

### Mainnet Deployment
TBA
