const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const strategyABI = ["function rebalanceNeeded() external view returns (bool)", "function rebalance() external returns (uint256)"];
// on tenderly fork
const strategyAddress = '0x08dd8c0b5E660800970410f6Ab3e61727599501F';

// execute rebalance operation if its necessary using a relay signer
async function performRebalance(signer, address) {
  const strategy = new ethers.Contract(address, strategyABI, signer);
  
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
 
  await performRebalance(client.relaySigner, strategyAddress);
}

// Unit testing with ethers
exports.main = performRebalance;

// To run locally (this code will not be executed in actions)
if (require.main === module) {
  require('dotenv').config();
  const { DEPLOYER_PK: pk, BASE_FORK_RPC_URL: tenderlyRPC } = process.env;
  const provider = new ethers.providers.JsonRpcProvider(tenderlyRPC);
  const signer = new ethers.Wallet(pk, provider);

  exports.main(signer, strategyAddress)
    .then(() => process.exit(0))
    .catch(error => { console.error(error); process.exit(1); });
}