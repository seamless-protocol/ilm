const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const strategyABI = ["function rebalanceNeeded() external view returns (bool)", "function rebalance() external returns (uint256)"];
// on tenderly fork
const strategyAddress = '0x08dd8c0b5E660800970410f6Ab3e61727599501F';

// execute rebalance operation if its necessary
async function performRebalance(strategy) {
  try {
    if (await strategy.rebalanceNeeded()) {
        const tx = await strategy.rebalance();
        console.log(`Called rebalance in ${tx.hash}`);
        return { tx: tx.hash };
    } else {
      console.log('Rebalance not needed.');
    }
  } catch (err) {
    console.error('An error occurred on rebalance call: ', err);
  }
}

// Entrypoint for the action
exports.handler = async function(credentials) {
  const client = new Defender(credentials);

  const strategy = new ethers.Contract(strategyAddress, strategyABI, client.relaySigner,);
 
  await performRebalance(strategy);
}

// unit testing
exports.performRebalance = performRebalance;