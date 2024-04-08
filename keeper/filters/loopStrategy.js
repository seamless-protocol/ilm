
const { ethers } = require("ethers");
const { KeyValueStoreClient } = require('defender-kvstore-client');
const { isStrategyAtRisk, isStrategyOverexposed, hasEPSDecreased, isSequencerOut, isOracleOut } = require("../actions/checks");
const { updateEPS, equityPerShare } = require("../actions/utils");

const depositSig = 'Deposit(address,address,uint256,uint256)';
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

// 0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e: 3x wstETH/WETH
const strategyInterestThreshold = {
    "0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e": ethers.BigNumber.from(ethers.utils.parseUnits('3.0', 27)), // 3% in RAY
};

// 0x4200000000000000000000000000000000000006: WETH
const debtTokenToStrategies = {
    "0x4200000000000000000000000000000000000006": ["0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e"],
};

const strategyABI = [
    "function rebalanceNeeded() external view returns (bool)",
    "function rebalance() external returns (uint256)",
    "function debt() external view returns (uint256)",
    "function collateral() external view returns (uint256)",
    "function currentCollateralRatio() external view returns (uint256)",
    "function getCollateralRatioTargets() external view returns (tuple(uint256,uint256,uint256,uint256,uint256))",
    "function equity() external view returns (uint256)"
];

const oracleABI = [
    "function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)",
    "function latestAnswer() external view returns (uint256)"
];

const poolABI = [
    "function getReserveData(address) external view returns (tuple(uint256,uint128,uint128,uint128,uint128,uint128,uint40,uint16,address,address,address,address,uint128,uint128,uint128))",
];

const RPC_URL = 'some_rpc_url';

const healthFactorThreshold = ethers.BigNumber.from(ethers.utils.parseUnits('1.1', 8)); //value used for testing

exports.handler = async function (payload) {
    const conditionRequest = payload.request.body;
    const matches = [];
    const events = conditionRequest.events;

    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);

    const store = new KeyValueStoreClient(payload);

    let strategy;
    let strategiesToRebalance = [];

    for (let evt of events) {
        for (let reason of evt.matchReasons) {
            let reasonSig = reason.signature;

            if (reasonSig == withdrawSig || reasonSig == depositSig) {
                strategy = new ethers.Contract(ethers.utils.getAddress(reason.address), strategyABI, provider);
                
                let riskState = await isStrategyAtRisk(strategy, healthFactorThreshold);
                let exposureState = await isStrategyOverexposed(strategy);
                let EPSState  = await hasEPSDecreased(store, strategy);

                matches.push({
                    hash: evt.hash,
                    metadata: {
                        "type": "withdrawOrDeposit",
                        "riskState": riskState,
                        "exposureState": exposureState,
                        "EPSState": EPSState
                    }
                });
            }

            if (reasonSig == priceUpdateSig) {
                let oracle = new ethers.Contract(ethers.utils.getAddress(reason.address), oracleABI, provider);
                
                let latestAnswer = await oracle.latestAnswer();

                // sequencer oracle event emission is not linked to any strategy rebalances
                if (latestAnswer != 0 || latestAnswer != 1) {
                    for (let affectedStrategy of oracleToStrategies[reason.address]) {
                        strategy = new ethers.Contract(affectedStrategy, strategyABI, provider);
    
                        // update equityPerShare because price fluctuations may alter it organically
                        updateEPS(store, strategy, equityPerShare(strategy));
    
                        if (await strategy.rebalanceNeeded()) {
                            strategiesToRebalance.push(affectedStrategy);
                        }
                    }
                }
               
                matches.push({
                    hash: evt.hash,
                    metadata: {
                        "type": "priceUpdate",
                        "strategiesToRebalance": strategiesToRebalance,
                        "sendOracleOutageAlert": await isOracleOut(oracle), 
                        "sendSequencerOutageAlert": await isSequencerOut(oracle)

                    }
                });
            }

            if (
                reasonSig == poolBorrowSig
                || reasonSig == poolRepaySig
                || reasonSig == poolWithdrawSig
                || reasonSig == poolSupplySig
                || reasonSig == poolLiquidationSig
            ) {
                // on all events, reserve/collateral asset is first argument, which correlates to asset 
                // to query
                let reserveAddress = reason.args[0];

                if (reserveAddress in debtTokenToStrategies) {
                    let pool = new ethers.Contract(ethers.utils.getAddress(reason.address), poolABI, provider);

                    let reserveData = await pool.getReserveData(reserveAddress);
                    let variableBorrowRate = reserveData[3];
                    
                    matches.push({
                        hash: evt.hash,
                        metadata: {
                            "type": "borrowRate",
                            "currBorrowRate": variableBorrowRate,
                            "affectedStrategies": debtTokenToStrategies[reserveAddress]
                        }
                    });
                }
            }
        }
    }
    return { matches }
}


