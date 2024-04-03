const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { equityPerShare } = require("./utils");

const strategyABI = [
  "function rebalanceNeeded() external view returns (bool)",
  "function rebalance() external returns (uint256)",
  "function debt() external view returns (uint256)",
  "function collateral() external view returns (uint256)",
  "function currentCollateralRatio() external view returns (uint256)",
  "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))"
];

const healthFactorThreshold = ethers.BigNumber.from(ethers.utils.parseUnits('1.1', 8));  //value used for testing

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
exports.handler = async function (payload, context) {
  const client = new Defender(payload);
  const store = new KeyValueStoreClient(payload);
  const { notificationClient } = context;

  const provider = client.relaySigner.getProvider();
  const signer = client.relaySigner.getSigner(provider, { speed: 'fast' });

  const events = payload.request.body.events;

  for (let evt of events) {
    if ('type' in evt.metadata && evt.metadata.type == "priceUpdate") {
      for (let strategyToRebalance of evt.metadata.strategiesToRebalance) {
        const strategy = new ethers.Contract(strategyToRebalance, strategyABI, signer);

        await performRebalance(strategy);
      
        // update equityPerShare because performRebalance may affect it
        updateEPS(store, strategy, equityPerShare(strategy));
      
        await sendHealthFactorAlert(notificationClient, strategy, healthFactorThreshold);
        await sendExposureAlert(notificationClient, strategy);
      }
    }
  }

}

// unit testing
exports.performRebalance = performRebalance;