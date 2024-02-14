# ILM Keepers

Contained herein are a set of OpenZeppelin Defender Actions, and their tests, for upkeeping the ILM Strategies.

# OZ Defender
The `rebalance.js` script should be pasted in the `OZ Action` interface, to function as intended.

Additionaly, the `strategyAddress` variable in the script needs to be altered for each action, to match the strategy to maintain.

# Test
`yarn test:keepers`