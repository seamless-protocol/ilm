const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const BASE = ethers.BigNumber.from(ethers.utils.parseUnits('1.0', 8)); // value used for percentage calculations (1e8 == 100%)

// check whether health factor is below threshhold
async function isStrategyAtRisk(strategy, threshold) {
    try {
        const debtUSD = ethers.BigNumber.from(await strategy.debt());
        const collateralUSD = ethers.BigNumber.from(await strategy.collateral());

        const healthFactor = collateralUSD.mul(BASE).div(debtUSD);

        return {
            isAtRisk: healthFactor.lt(threshold),
            healthFactor: healthFactor
        };
    } catch (err) {
        console.error('An error has occurred during health factor check: ', err);
    }
}

// check whether collateral ratio is beneath minForRebalance indicating overexposure
async function isStrategyOverexposed(strategy) {
    try {
        const currentCR = ethers.BigNumber.from((await strategy.currentCollateralRatio()).toString());
        const minForRebalance = ethers.BigNumber.from(((await strategy.getCollateralRatioTargets())[1]).toString());
        
       return {
            isOverExposed: currentCR.lt(minForRebalance),
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

async function isOracleOut(store, oracle) {
    const lastUpdate = await store.get(oracle.address);

    if (lastUpdate !== null && value !== undefined) {
        let secondSinceLastUpdate = value - Math.floor(Date.now() / 1000);

        return secondSinceLastUpdate > 24 * 60 * 60 + 60;
    }

    await store.put(oracle, await oracle.latestRoundData()[3]);
}

async function sendOracleOutageAlert(notificationClient) {
    try {
        notificationClient.send({
            channelAlias: 'seamless-alerts',
            subject: 'ORACLE OUTAGE',
            message: `Seconds elapsed since last update are more than ${24 * 60 * 60 + 60} seconds`,
        });
    } catch (error) {
        console.error('Failed to send notification', error);
    }
}

async function sendEPSAlert(notificationClient, store, strategy) {
    const prevEPS = await store.get(strategy.address);

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
    } else {
        console.log('EPS has not decreased.');
    }

    updateEPS(store, strategy, currentEPS);
}

async function isSequencerOut(oracle) {
    return await oracle.latestAnswer() == 1;
}

async function sendSequencerOutageAlert(notificationClient) {
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
    } else {
        console.log('Strategy is not at risk.');
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
    } else {
        console.log('Strategy is not overexposed.');
    }
}

async function sendBorrowRateNotification(notificationClient, currentRate, threshold) {
    if (
        ethers.BigNumber.from(currentRate.toString()).gte(threshold)
    ) {
        try {
            notificationClient.send({
                channelAlias: 'seamless-alerts',
                subject: 'LENDING POOL BORROW RATE IS LARGE',
                message: `Current rate is ${ethers.utils.formatEther(currentRate)} and threshold rate is ${threshold}`,
            });
        } catch (error) {
            console.error('Failed to send notification', error);
        }   
    } else {
        console.log('Borrow rate is below threshold.');
    }
}

async function updateEPS(store, strategy, currentEPS) {
    store.put(strategy, currentEPS);
}

// checkers
exports.isStrategyAtRisk = isStrategyAtRisk;
exports.isStrategyOverexposed = isStrategyOverexposed;
exports.checkAlertChannelsExist = checkAlertChannelsExist;
exports.isOracleOut = isOracleOut;
exports.isSequencerOut = isSequencerOut;

// utils
exports.equityPerShare = equityPerShare;
exports.updateEPS = updateEPS;

// notifications
exports.sendExposureAlert = sendExposureAlert;
exports.sendHealthFactorAlert = sendHealthFactorAlert;
exports.sendEPSAlert = sendEPSAlert;
exports.sendOracleOutageAlert = sendOracleOutageAlert;
exports.sendSequencerOutageAlert = sendSequencerOutageAlert;
exports.sendBorrowRateNotification = sendBorrowRateNotification;

