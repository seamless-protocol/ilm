const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const strategyABI = [
    "function debt() external view returns (uint256)",
    "function collateral() external view returns (uint256)",
    "function currentCollateralRatio() external view returns (uint256)",
    "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))"
];
const strategyAddress = '0x08dd8c0b5E660800970410f6Ab3e61727599501F';
const healthFactorThreshold = 10 ** 8; //value used for testing
const BASE = 10 ** 8; // value used for percentage calculations (1e8 == 100%)

// check whether health factor is below threshhold
async function isStrategyAtRisk(strategy) {
    try {
        const debtUSD = await strategy.debt();
        const collateralUSD = await strategy.collateral();

        const healthFactor = collateralUSD * BASE / debtUSD;

        return {
            isAtRisk: healthFactor <= healthFactorThreshold,
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

// checks that alert channels matching 'seamless-alerts' alias exist and returns them
async function checkAlertChannelsExist(client) {
    const notificationChannels = await client.monitor.listNotificationChannels();

    let alertChannels = notificationChannels.filter(channel => channel.name === 'seamless-alerts');

    if (alertChannels.length == 0) {
        console.error('No alert notification channels exist.');
    }
}

exports.handler = async function (credentials, context) {
    const client = new Defender(credentials);
    const { notificationClient } = context;
    const provider = client.relaySigner.getProvider();

    const strategy = new ethers.Contract(strategyAddress, strategyABI, provider);

    const { isAtRisk, healthFactor } = isStrategyAtRisk(strategy);
    const { isOverExposed, currentCR, minForRebalance } = isStrategyOverexposed(strategy);

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

exports.isStrategyAtRisk = isStrategyAtRisk;
exports.isStrategyOverexposed = isStrategyOverexposed;
exports.checkAlertChannelsExist = checkAlertChannelsExist;
exports.healthFactorThreshold = healthFactorThreshold;

