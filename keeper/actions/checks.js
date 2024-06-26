/// This file contains all checking logic for LoopStrategies. 
/// These checks determine whether a notification should be sent, thus all return
/// a boolean indicating whether a notificaiton should be sent or not.

const { ethers } = require("ethers");
const { equityPerShare, updateEPS } = require("./utils");

const BASE = ethers.BigNumber.from(ethers.utils.parseUnits('1.0', 8)); // value used for percentage calculations (1e8 == 100%)

// check whether health factor is below threshold
async function isStrategyAtRisk(strategy, threshold) {
    try {
        const debtUSD = ethers.BigNumber.from(await strategy.debtUSD());
        const collateralUSD = ethers.BigNumber.from(await strategy.collateralUSD());

        const healthFactor = collateralUSD.mul(BASE).div(debtUSD);

        return {
            isAtRisk: healthFactor.lt(threshold),
            threshold: threshold,
            healthFactor: healthFactor
        };
    } catch (err) {
        console.error('An error has occurred during health factor check: ', err);
      	throw err;
    }
}

// check whether collateral ratio is beneath minForRebalance indicating overexposure
async function isStrategyOverexposed(strategy) {
    try {
        const currentCR = ethers.BigNumber.from(
          (
          	await strategy.currentCollateralRatio()
          ).toString()
        );
        const minForRebalance = ethers.BigNumber.from(
          (
            (await strategy.getCollateralRatioTargets())[1]
          ).toString()
        );
        
       return {
            isOverExposed: currentCR.lt(minForRebalance),
            current: currentCR,
            min: minForRebalance
       };
        
    } catch (err) {
        console.error('An error has occured during collateral ratio check: ', err);
      	throw err;
    }
}

// checks if an oracle is out and update the last time it was updated
async function isOracleOut(store, oracle) {
    const lastUpdate = await store.get(oracle.address);
    const latestUpdate = await oracle.latestRoundData()[3];
	
	await store.put(oracle.address, latestUpdate.toString());

    if (lastUpdate !== null && lastUpdate !== undefined) {
        let secondSinceLastUpdate = parseInt(lastUpdate) - Math.floor(Date.now() / 1000);

        return {
            secondSinceLastUpdate: secondSinceLastUpdate,
            isOut: secondSinceLastUpdate > 24 * 60 * 60 + 60,
            oracleAddress: oracle.address
        };
    }

    
}

// checks if EPS has decreased between withdrawals / deposits, and updates latest EPS value
async function hasEPSDecreased(store, strategy) {
  	let prevEPS = await store.get(strategy.address);
  	try {
      	if (prevEPS === null || prevEPS === undefined) {
 			prevEPS = 0;
        }

    	const currentEPS = await equityPerShare(strategy);

    	await updateEPS(store, strategy.address, currentEPS);
      
      	console.log('prevEPS: ', prevEPS);
        console.log('currentEPS: ', currentEPS);

    	return {
        	strategyAddress: strategy.address,
        	hasEPSDecreased: ethers.BigNumber.from(prevEPS.toString()).lt(ethers.BigNumber.from(currentEPS.toString())),
        	prevEPS: prevEPS,
        	currentEPS: currentEPS
    	};
    } catch (err) {
    	console.error('An error occurred when attempting to check if EPS has decreased: ', err);
        console.log('prevEPS: ', prevEPS);
        throw err;
    }
}

// checks that alert channels matching 'seamless-alerts' alias exist and returns them
async function checkAlertChannelsExist(client) {
    const notificationChannels = await client.monitor.listNotificationChannels();

    let alertChannels = notificationChannels.filter(channel => channel.name === 'seamless-alerts');

    if (alertChannels.length == 0) {
        console.error('No alert notification channels exist.');
    }
}

exports.isStrategyAtRisk = isStrategyAtRisk;
exports.isStrategyOverexposed = isStrategyOverexposed;
exports.isOracleOut = isOracleOut;
exports.hasEPSDecreased = hasEPSDecreased;
exports.checkAlertChannelsExist = checkAlertChannelsExist;