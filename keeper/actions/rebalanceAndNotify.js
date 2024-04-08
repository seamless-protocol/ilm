const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { equityPerShare, updateEPS } = require("./utils");
const { sendHealthFactorAlert, sendExposureAlert, sendEPSAlert, sendOracleOutageAlert, sendSequencerOutageAlert, sendBorrowRateAlert} = require("./alerts");

const strategyABI = [
  "function rebalanceNeeded() external view returns (bool)",
  "function rebalance() external returns (uint256)",
  "function debt() external view returns (uint256)",
  "function collateral() external view returns (uint256)",
  "function currentCollateralRatio() external view returns (uint256)",
  "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))",
  "function equity() external view returns (uint256)"
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

  const metadata = payload.request.body.metadata;
  
  if ('type' in metadata && metadata.type == 'withdrawOrDeposit') {
      console.log('Processing states after withdrawal or deposit...');

      if (metadata.riskState.isAtRisk) {
        await sendHealthFactorAlert(notificationClient, riskState.threshold, riskState.healthFactor);
        console.log('Sent health factor alert.');
      } else {
        console.log(`Health factor is deemed to be safe at: ${riskState.healthFactor}.`);
      }

      if (metadata.exposureState.isOverExposed) {
        await sendExposureAlert(notificationClient, exposureState.current, exposureState.min);
        console.log('Sent exposure alert.');
      } else {
        console.log(`Exposure is deemed to be fine at ${exposureState.current}.`);
      }

      if (metadata.EPSState.hasEPSDecreased) {
        await sendEPSAlert(notificationClient, EPSState.strategyAddress, EPSState.currentEPS, EPSState.currentEPS);
        console.log('EPS alert has been sent out.');
      } else {
        console.log(`No EPS alert was sent as previous EPS was ${EPSState.prevEPS} and current EPS is ${EPSState.currentEPS}`);
      }

      console.log('States finished processing - alerts may have been sent out.');
  }

  if ('type' in metadata && metadata.type == "priceUpdate") {
    if (metadata.strategiesToRebalance.length != 0) {
       try {
        console.log('Attempting to rebalance strategies...');
        const rebalancePromises = evt.metadata.strategiesToRebalance.map(async (strategyToRebalance) => {
          const strategy = new ethers.Contract(strategyToRebalance, strategyABI, signer);
        
          await performRebalance(strategy);
          
          // update equityPerShare because performRebalance may affect it
          updateEPS(store, strategy, equityPerShare(strategy));
          
          await sendHealthFactorAlert(notificationClient, strategy, healthFactorThreshold);
          await sendExposureAlert(notificationClient, strategy);
        });

        await Promise.all(rebalancePromises);
       } catch(err) {
        console.log('There was an error when attempting to rebalance affected strategies.');
       }        
    } else {
      console.log('No strategies needing rebalance have been detected.');
    }

    if (metadata.oracleState.isOut) {
      await sendOracleOutageAlert(notificationClient);
      console.log('Sent oracle outage alert.');
    } else {
      console.log('Oracle outage alert has not been sent.');
    }
    
    if (metadata.isSequencerOut) {
      await sendSequencerOutageAlert(notificationClient);
      console.log('Sent sequencer outage alert.');
    } else {
      console.log('Sequencer outage alert has not been sent.');
    }
  }

  if ('type' in metadata && metadata.type == 'borrowRate') {
    await sendBorrowRateAlert(notificationClient, metadata.reserve, metadata.currBorrowRate, metadata.affectedStrategies);
    console.log('Sent borrow rate alert.');
  }

  
}

// unit testing
exports.performRebalance = performRebalance;