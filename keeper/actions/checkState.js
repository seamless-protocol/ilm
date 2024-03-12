const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { isStrategyAtRisk, isStrategyOverexposed } = require("./utils");

const strategyABI = [
    "function debt() external view returns (uint256)",
    "function collateral() external view returns (uint256)",
    "function currentCollateralRatio() external view returns (uint256)",
    "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))"
];
const strategyAddress = '0x08dd8c0b5E660800970410f6Ab3e61727599501F';
const healthFactorThreshold = 10 ** 8; //value used for testing

exports.handler = async function (credentials, context) {
    const client = new Defender(credentials);
    const { notificationClient } = context;
    const provider = client.relaySigner.getProvider();
    
    const strategy = new ethers.Contract(strategyAddress, strategyABI, provider);

    const { isAtRisk, healthFactor } = isStrategyAtRisk(strategy, healthFactorThreshold);
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
exports.healthFactorThreshold = healthFactorThreshold;

