const { expect } = require('chai');
const sinon = require('sinon');
const { isStrategyOverexposed } = require('../alerts/collateralRatio');

describe('isStrategyOverexposed', () => {
    let strategyStub;

    beforeEach(() => {
        strategyStub = {
            currentCollateralRatio: sinon.stub(),
            getCollateralRatioTargets: sinon.stub() 
        };
    });

    afterEach(() => {
        sinon.restore();
    });

    it('returns false, and, currentCollateralRatio and minForRebalance values when currentCollateralRatio value is above minForRebalance value', async () => {
        strategyStub.currentCollateralRatio.resolves(100);
        strategyStub.getCollateralRatioTargets.resolves([100, 90, 110, 99, 101]);

        const result = await isStrategyOverexposed(strategyStub);
        
        expect(result.isOverExposed).to.eq(false);
        expect(result.current).to.eq(100);
        expect(result.min).to.eq(90);
    });

    it('returns true, and, currentCollateralRatio and minForRebalance values when currentCollateralRatio value is beneath minForRebalance value', async () => {
        strategyStub.currentCollateralRatio.resolves(85);
        strategyStub.getCollateralRatioTargets.resolves([100, 90, 110, 99, 101]);

        const result = await isStrategyOverexposed(strategyStub);
        
        expect(result.isOverExposed).to.eq(true);
        expect(result.current).to.eq(85);
        expect(result.min).to.eq(90);
    });

    it('should handle errors', async () => {
        strategyStub.currentCollateralRatio.rejects(new Error('error thrown'));
        const consoleErrorStub = sinon.stub(console, 'error');

        await isStrategyOverexposed(strategyStub);

        sinon.assert.calledOnce(consoleErrorStub);
        expect(consoleErrorStub.firstCall.args[0]).to.include('An error has occured during collateral ratio check: ');

        console.error.restore();
    });
});
