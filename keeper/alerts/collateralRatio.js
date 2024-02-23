const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');

const strategyABI = [
    "function currentCollateralRatio() external view returns (uint256)",
    "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))"
];
const strategyAddress = '';

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

exports.handler = async function (credentials, context) {
    const client = new Defender(credentials);

    // checkAlertChannelsExist(client); can add later
    const { notificationClient } = context;

    const provider = client.relaySigner.getProvider();
    const signer = client.relaySigner.getSigner(provider, { speed: 'fast' });

    const strategy = new ethers.Contract(strategyAddress, strategyABI, signer);

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

exports.isStrategyOverexposed = isStrategyOverexposed;
