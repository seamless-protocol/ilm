const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const BASE = 10 ** 8; // value used for percentage calculations (1e8 == 100%)

// check whether health factor is below threshhold
async function isStrategyAtRisk(strategy, threshold) {
    try {
        const debtUSD = await strategy.debt();
        const collateralUSD = await strategy.collateral();

        const healthFactor = collateralUSD * BASE / debtUSD;

        return {
            isAtRisk: healthFactor <= threshold,
            healthFactor: healthFactor
        };
    } catch (err) {
        console.error('An error has occurred during health factor check: ', err);
    }
}

// check whether collateral ratio is beneath minForRebalance indicating overexposure
async function isStrategyOverexposed(strategy) {
    try {
        const currentCR = await strategy.currentCollateralRatio();
        const minForRebalance = (await strategy.getCollateralRatioTargets())[1];
        
       return {
            isOverExposed: currentCR < minForRebalance,
            current: currentCR,
            min: minForRebalance
       };
        
    } catch (err) {
        console.error('An error has occured during collateral ratio check: ', err);
    }
}

// get current equity per share
async function equityPerShare(strategy) {
    try {
        const equityBN = ethers.BigNumber.from((await strategy.equity()).toString());
        const sharesBN = ethers.BigNumber.from((await strategy.totalSupply()).toString());

        return equityBN.div(sharesBN);

    } catch (err) {
        console.error('An error has occured during equityPerShare calculation: ', err);
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

async function sendOracleOutageAlert(notificationClient, store, oracle) {
    //TODO: CHECK FOR FIRST CALLBACK, WHETHER THIS IS NULL OR NOT
    const secondSinceLastUpdate = await store.get(oracle) - Math.floor(Date.now() / 1000);
    
    // check if the different of timestamp updates is more than 1 day and 1 minute
    // as oracles update at least once per day
    if (secondSinceLastUpdate > (24 * 60 * 60 + 60)) {
        try {
            notificationClient.send({
                channelAlias: 'seamless-alerts',
                subject: 'ORACLE OUTAGE',
                message: `Seconds elapsed since last update are ${secondSinceLastUpdate} which are more than ${24 * 60 * 60 + 60} seconds`,
            });
        } catch (error) {
            console.error('Failed to send notification', error);
        }
    }

    await store.put(oracle, await oracle.latestRoundDatate()[3]);
}

async function sendEPSAlert(notificationClient, store, strategy) {
    const prevEPS = await store.get(strategy);

    const currentEPS = equityPerShare(strategy);

    if (prevEPS > currentEPS) {
        try {
            notificationClient.send({
                channelAlias: 'seamless-alerts',
                subject: 'STRATEGY EQUITY_PER_SHARE DECREASED FROM WITHDRAWAL',
                message: `Current strategy EPS is ${currentEPS} and previous EPS was ${prevEPS} `,
            });
        } catch (error) {
            console.error('Failed to send notification', error);
        }
    }

    updateEPS(store, strategy, currentEPS);
}

async function sendSequencerOutageAlert(notificationClient, oracle) {
    if(await oracle.latestAnswer() == 1) {
        try {
            notificationClient.send({
                channelAlias: 'seamless-alerts',
                subject: 'SEQUENCER OUTAGE',
                message: `Latest answer of sequencer oracle is 1.`,
            });
        } catch (error) {
            console.error('Failed to send notification', error);
        }
    }
}

async function sendHealthFactorAlert(notificationClient, strategy, healthFactorThreshold) {
    const { isAtRisk, healthFactor } = isStrategyAtRisk(strategy, healthFactorThreshold);

    if (isAtRisk) {
        try {
            notificationClient.send({
                channelAlias: 'seamless-alerts',
                subject: 'HEALTH FACTOR THRESHOLD BREACHED',
                message: `Current strategy health factor threshold is: ${healthFactorThreshold} and healthFactor is ${healthFactor} `,
            });
        } catch (error) {
            console.error('Failed to send notification', error);
        }
    }
}

async function sendExposureAlert(notificationClient, strategy) {
    const { isOverExposed, currentCR, minForRebalance } = isStrategyOverexposed(strategy);

    if (isOverExposed) {
        try {
            notificationClient.send({
                channelAlias: 'seamless-alerts',
                subject: 'STRATEGY IS OVEREXPOSED',
                message: `Current collateral ratio is ${currentCR} and minForRebalance ratio is ${minForRebalance} `,
            });
        } catch (error) {
            console.error('Failed to send notification', error);
        }
    }
}

async function updateEPS(store, strategy, currentEPS) {
    store.put(strategy, currentEPS);
}
     
exports.isStrategyAtRisk = isStrategyAtRisk;
exports.isStrategyOverexposed = isStrategyOverexposed;
exports.equityPerShare = equityPerShare;
exports.checkAlertChannelsExist = checkAlertChannelsExist;
exports.updateEPS = updateEPS;
exports.sendExposureAlert = sendExposureAlert;
exports.sendHealthFactorAlert = sendHealthFactorAlert;
exports.sendEPSAlert = sendEPSAlert;
exports.sendOracleOutageAlert = sendOracleOutageAlert;
exports.sendSequencerOutageAlert = sendSequencerOutageAlert;

