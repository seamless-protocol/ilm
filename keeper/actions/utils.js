const { ethers } = require("ethers");

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

// store new value of equity per share in OZ KV store
async function updateEPS(store, strategy, currentEPS) {
    store.put(strategy, currentEPS);
}

exports.equityPerShare = equityPerShare;
exports.updateEPS = updateEPS;


