const { expect } = require("chai");
const { main } = require("../actions/rebalance");
const { ethers, Contract } = require('ethers');
const LoopStrategyJSON = require('../../out/LoopStrategy.sol/LoopStrategy.json');

describe("rebalance action", function () {
    let strategy, signer, snap;
    // CbETH strategy on fork
    const strategyAddress = '0x08dd8c0b5E660800970410f6Ab3e61727599501F';
    // fork with FE testing (must be same as one in `rebalance.js` script)
    const BASE_ILM_FORK_RPC_URL = 'https://rpc.tenderly.co/fork/1aec2019-21bb-4c84-a7c8-148fa6527483';
    const provider = new ethers.providers.JsonRpcProvider(BASE_ILM_FORK_RPC_URL);

    before(async function () {
        this.timeout('10000');
        signer = provider.getSigner('0xf6ded1795513c7744a3198a45b97dc55e4e12729');

        strategy = new Contract(strategyAddress, LoopStrategyJSON.abi, signer);
    });

    beforeEach(async () => {
        snap = await provider.send("evm_snapshot", []);
    });

    afterEach(async () => {
        await provider.send("evm_revert", [snap]);
    });

    // Emulates autotask run
    const run = () => main(signer, strategyAddress);

    it("does not rebalance if rebalanceNeeded is false", async function () {
        this.timeout('10000');

        expect(await strategy.rebalanceNeeded()).to.be.false;
        const oldCR = await strategy.currentCollateralRatio();

        await run();

        expect(oldCR).to.deep.eq(await strategy.currentCollateralRatio());
    });

    it("rebalances if rebalanceNeeded is true", async function () {
        this.timeout('10000');
        let targets = await strategy.getCollateralRatioTargets();

        const oldCR = await strategy.currentCollateralRatio();
        const newTargets = [
            ethers.BigNumber.from('170000000'),
            ethers.BigNumber.from('167000000'),
            ethers.BigNumber.from('173000000'),
            ethers.BigNumber.from('170000000'),
            ethers.BigNumber.from('170000000'),
        ];
        
        expect(await strategy.rebalanceNeeded()).to.be.false;

        await strategy.setCollateralRatioTargets(newTargets);
        targets = await strategy.getCollateralRatioTargets();

        expect(await strategy.rebalanceNeeded()).to.be.true;

        await run();
        
        expect(ethers.BigNumber.from(oldCR)).to.not.eq(ethers.BigNumber.from(await strategy.currentCollateralRatio()));
        expect(await strategy.rebalanceNeeded()).to.be.false;
    });
});
