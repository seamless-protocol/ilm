const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { KeyValueStoreClient } = require('defender-kvstore-client');

const strategyABI = [
    "function equity() external view returns (uint256)",
    "function totalSupply() external view returns (uint256)"
];
const strategyAddress = '';
const tolerance = 10;

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

exports.handler = async function (credentials, context, payload) {
    const client = new Defender(credentials);
    const store = new KeyValueStoreClient(context);

    const { notificationClient } = context;

    const provider = client.relaySigner.getProvider();

    const strategy = new ethers.Contract(payload.request.body.metadata.strategy, strategyABI, provider);

    const currentEPS = equityPerShare(strategy);

    const prevEPS = await store.get(strategy);

    store.put(strategy, currentEPS);

    if (prevEPS < currentEPS) {
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
}

exports.isStrategyOverexposed = isStrategyOverexposed;
