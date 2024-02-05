const { ethers } = require("ethers");
const { DefenderRelaySigner, DefenderRelayProvider } = require('defender-relay-client/lib/ethers');
const { LoopStrategyJSON } = require('../out/LoopStrategy.sol/LoopStrategy.json');

// Entrypoint for the action
exports.handler = async function(event) {
  const strategyAddress = '';

  // Initialize relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: 'fast' });

  // Create contract instance from the signer and use it to send a tx
  const contract = new ethers.Contract(strategyAddress, LoopStrategyJSON.abi, signer);

  if (await contract.rebalanceNeeded()) {
    try {
        const tx = await contract.rebalance();
        console.log(`Called rebalance in ${tx.hash}`);
        return { tx: tx.hash };
    } catch (err) {
        console.error('An unexpected error occurred: ', err);
    }
  }
}