const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const strategyABI = ["function rebalanceNeeded() external view returns (bool)", "function rebalance() external returns (uint256)"];

// 0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e: 3x wstETH-ETH
// 0x2FB1bEa0a63F77eFa77619B903B2830b52eE78f4: 1.5x ETH-USDC
const strategyAddresses = ['0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e', '0x2FB1bEa0a63F77eFa77619B903B2830b52eE78f4']

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
exports.handler = async function (credentials) {
  const client = new Defender(credentials);

  const provider = client.relaySigner.getProvider();
  const signer = client.relaySigner.getSigner(provider, { speed: 'fast' });

  for (let strategyAddress of strategyAddresses) {
  	let strategy = new ethers.Contract(strategyAddress, strategyABI, signer);

  	await performRebalance(strategy);
  }
}
