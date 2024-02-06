const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');
const { LoopStrategyJSON } = require('../../out/LoopStrategy.sol/LoopStrategy.json');

const strategyABI = LoopStrategyJSON.abi;
const strategyAddress = '';

// execute rebalance operation if its necessary using a relay signer
async function performRebalance(signer, address) {
  const strategy = new ethers.Contract(address, strategyABI, signer);

  if (await strategy.rebalanceNeeded()) {
    try {
      const tx = await contract.rebalance();
      console.log(`Called rebalance in ${tx.hash}`);
      return { tx: tx.hash };
    } catch (err) {
        console.error('An unexpected error occurred: ', err);
    }
  } else {
    console.log('Rebalance not needed.');
  }
  
}

// Entrypoint for the action
exports.handler = async function(event) {
  // Initialize relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: 'fast' });

  await performRebalance(signer, strategyAddress);
}

// Unit testing
exports.main = performRebalance;

// To run locally (this code will not be executed in actions)
if (require.main === module) {
  require('dotenv').config();
  const { API_KEY: apiKey, API_SECRET: apiSecret } = process.env;
  exports.handler({ apiKey, apiSecret })
    .then(() => process.exit(0))
    .catch(error => { console.error(error); process.exit(1); });
}