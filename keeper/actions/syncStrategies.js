const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { sendNotifications } = require("./utils");
const { performRebalance } = require("./rebalance");

// 0xa669E5272E60f78299F4824495cE01a3923f4380: wstETH-ETH
// 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70: ETH-USD
const oracleToStrategies = {
    "0xa669E5272E60f78299F4824495cE01a3923f4380": ["0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e"],
    "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70": ["0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e"],
};

const healthFactorThreshold = 10 ** 8; //value used for testing

const strategyABI = [
    "function rebalanceNeeded() external view returns (bool)", 
    "function rebalance() external returns (uint256)",
    "function debt() external view returns (uint256)",
    "function collateral() external view returns (uint256)",
    "function currentCollateralRatio() external view returns (uint256)",
    "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))"
];

exports.handler = async function (credentials, context, payload) {
    const client = new Defender(credentials);

    const provider = client.relaySigner.getProvider();
    const signer = client.relaySigner.getSigner(provider, { speed: 'fast' });

    const { notificationClient } = context;

    const events = payload.request.body.events;
    
    let strategy; 

    for(let evt of events) {
        if(evt.metadata.notificationType == 'priceUpdate') {
            let affectedStrategies = oracleToStrategies[evt.metadata.oracle];

            for(let affectedStrategy of affectedStrategies) {
                strategy = new ethers.Contract(affectedStrategy, strategyABI, signer);

                await performRebalance(strategy);
                await sendNotifications(notificationClient, strategy, healthFactorThreshold);
            }
        }

        if(evt.metadata.notificationType == 'withdrawal') {
            strategy = new ethers.Contract(evt.metadata.strategy, strategyABI, signer);

            await sendNotifications(notificationClient, strategy, healthFactorThreshold);
        }
    }
}