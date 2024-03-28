
const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { KeyValueStoreClient } = require('defender-kvstore-client');
const { sendOracleOutageAlert, sendExposureAlert, sendHealthFactorAlert, sendEPSAlert, sendSequencerOutageAlert } = require("./utils");
const { performRebalance } = require("./rebalance");

const withdrawSig = 'Withdraw(address,address,address,uint256,uint256)';
const priceUpdateSig = 'AnswerUpdated(int256,uint256,uint256)';
const poolLiquidationSig = 'LiquidationCall(address,address,address,uint256,uint256,address,bool)';
const poolBorrowSig = 'Borrow(address,address,address,uint256,uint8,uint256,uint16)';
const poolRepaySig = 'Repay(address,address,address,uint256,bool)'
const poolWithdrawSig = 'Withdraw(address,address,address,uint256)';
const poolSupplySig = 'Supply(address,address,address,uint256,uint16)';

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

exports.handler = async function (payload) {
    const conditionRequest = payload.request.body;
    const matches = [];
    const events = conditionRequest.events;

    for (let evt of events) {
        if (evt.matchReasons.signature == withdrawSig) {

            let strategy = new ethers.Contract(evt.matchedChecksumAddress, strategyABI, signer);

            await sendHealthFactorAlert(notificationClient, strategy, healthFactorThreshold);
            await sendExposureAlert(notificationClient, strategy);
            await sendEPSAlert(notificationClient, store, strategy);

            matches.push({
                hash: evt.hash,
                metadata: {
                    "notificationType": "withdrawal",
                    "strategy": evt.matchedChecksumAddress
                }
            });
        }

        if (evt.matchReasons.signature == priceUpdateSig) {
            matches.push({
                hash: evt.hash,
                metadata: {
                    "notificationType": "priceUpdate",
                    "oracle": evt.matchedChecksumAddress
                }
            })
        }
        if (evt.matchReasons.signature == poolSupplySig) {
            matches.push({
                hash: evt.hash,
                metadata: {
                    "notificationType": "interestRateUpdate",

                }
            })
        }
    }
    return { matches }
}

