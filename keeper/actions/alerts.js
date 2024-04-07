
/// This file contains only helpers to send notifications via the OZ Defender notification client.
/// No checking logic is contained herein.

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

async function sendHealthFactorAlert(notificationClient, healthFactorThreshold, healthFactor) {
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

async function sendEPSAlert(notificationClient, strategyAddress, currentEPS, prevEPS) {
    try {
        notificationClient.send({
            channelAlias: 'seamless-alerts',
            subject: 'STRATEGY EQUITY_PER_SHARE DECREASED FROM WITHDRAWAL',
            message: `For strategy: ${strategyAddress}, EPS is ${currentEPS} and previous EPS was ${prevEPS} `,
        });
    } catch (error) {
        console.error('Failed to send notification', error);
    }
}

async function sendExposureAlert(notificationClient, currentCR, minForRebalance) {
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

async function sendBorrowRateNotification(notificationClient, currentRate, threshold) {
    try {
        notificationClient.send({
            channelAlias: 'seamless-alerts',
            subject: 'LENDING POOL BORROW RATE IS LARGE',
            message: `Current rate is ${ethers.utils.formatEther(currentRate)} and threshold rate is ${threshold}`,
        });
    } catch (error) {
        console.error('Failed to send notification', error);
    }   
    
}

exports.sendOracleOutageAlert = sendOracleOutageAlert;
exports.sendSequencerOutageAlert = sendSequencerOutageAlert;
exports.sendHealthFactorAlert = sendHealthFactorAlert;
exports.sendEPSAlert = sendEPSAlert;
exports.sendExposureAlert = sendExposureAlert;
exports.sendBorrowRateNotification = sendBorrowRateNotification;