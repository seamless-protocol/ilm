const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { KeyValueStoreClient } = require('defender-kvstore-client');
const { sendOracleOutageAlert, sendExposureAlert, sendHealthFactorAlert, sendEPSAlert, sendSequencerOutageAlert } = require("./utils");
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

const oracleABI = [
    "function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)",
    "function latestAnswer() external view returns (uint256)"
];

exports.handler = async function (credentials, context, payload) {
    const client = new Defender(credentials);
    const store = new KeyValueStoreClient(credentials);

    const provider = client.relaySigner.getProvider();
    const signer = client.relaySigner.getSigner(provider, { speed: 'fast' });

    const { notificationClient } = context;

    const events = payload.request.body.events;

    let strategy;
    const oracle = new ethers.Contract(evt.metadata.oracle, oracleABI, provider);

    for (let evt of events) {
        if (evt.metadata.notificationType == 'priceUpdate') {
            let affectedStrategies = oracleToStrategies[evt.metadata.oracle];

            for (let affectedStrategy of affectedStrategies) {
                strategy = new ethers.Contract(affectedStrategy, strategyABI, signer);

                await performRebalance(strategy);

                // update equityPerShare because price fluctuations may alter it organically
                updateEPS(strategy);
                await sendHealthFactorAlert(notificationClient, strategy, healthFactorThreshold);
                await sendExposureAlert(notificationClient, strategy);
            }

            await sendOracleOutageAlert(notificationClient, store, oracle);
            await sendSequencerOutageAlert(notificationClient, oracle);
        }

        if (evt.metadata.notificationType == 'withdrawal') {
            strategy = new ethers.Contract(evt.metadata.strategy, strategyABI, provider);

            // no udpate to equity per share because withdrawals should never decrease it
            await sendHealthFactorAlert(notificationClient, strategy, healthFactorThreshold);
            await sendExposureAlert(notificationClient, strategy);
            await sendEPSAlert(notificationClient, store, strategy);
        }
    }
}