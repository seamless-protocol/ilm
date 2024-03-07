const { expect } = require('chai');
const sinon = require('sinon');
const { isStrategyOverexposed, isStrategyAtRisk, checkAlertChannelsExist, healthFactorThreshold } = require('../alerts/checkState');

describe('checkState', () => {
    let strategyStub;
    
    beforeEach(() => {
        strategyStub = {
            currentCollateralRatio: sinon.stub(),
            getCollateralRatioTargets: sinon.stub(),
            debt: sinon.stub(),
            collateral: sinon.stub()
        };
    });

    afterEach(() => {
        sinon.restore();
    });

    describe('isStrategyOverexposed', () => {
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
    
    describe('isStrategyAtRisk', () => {    
        it('returns false and healthFactor value when healthFactor is above healthFactorThreshold', async () => {
            strategyStub.debt.resolves(10**8);
            strategyStub.collateral.resolves(healthFactorThreshold + 1);
    
            const result = await isStrategyAtRisk(strategyStub);
            
            expect(result.isAtRisk).to.eq(false);
            expect(result.healthFactor).to.eq(healthFactorThreshold + 1);
        });
    
        it('returns true and healthFactor value when healthFactor is below healthFactorThreshold', async () => {
            strategyStub.debt.resolves(10**8);
            strategyStub.collateral.resolves(healthFactorThreshold - 1);
    
            const result = await isStrategyAtRisk(strategyStub);
    
            expect(result.isAtRisk).to.eq(true);
            expect(result.healthFactor).to.eq(healthFactorThreshold - 1);
        });
    
        it('should handle errors', async () => {
            strategyStub.debt.rejects(new Error('error thrown'));
            const consoleErrorStub = sinon.stub(console, 'error');
    
            await isStrategyAtRisk(strategyStub);
    
            sinon.assert.calledOnce(consoleErrorStub);
            expect(consoleErrorStub.firstCall.args[0]).to.include('An error has occurred during health factor check: ');
    
            console.error.restore();
        });
    });
    
    describe('checkAlertChannelsExist', () => {
        let clientStub;
    
        beforeEach(() => {
            clientStub = {
                monitor: {
                  listNotificationChannels: sinon.stub()
                }
              };
        });
    
        it('handles errors when array returned is empty', async () => {
            clientStub.monitor.listNotificationChannels.resolves([]);
    
            const consoleErrorStub = sinon.stub(console, 'error');
    
            await checkAlertChannelsExist(clientStub);
    
            sinon.assert.calledOnce(consoleErrorStub);
            sinon.assert.calledWith(consoleErrorStub, 'No alert notification channels exist.');
    
            console.error.restore();
        });
    
        it('handles errors when array returned is non-empty but no names resolve to `seamless-alerts`', async () => {
            clientStub.monitor.listNotificationChannels.resolves([
                {
                    name: 'not-seamless-alerts'
                }
            ]);
    
            const consoleErrorStub = sinon.stub(console, 'error');
    
            await checkAlertChannelsExist(clientStub);
    
            sinon.assert.calledOnce(consoleErrorStub);
            sinon.assert.calledWith(consoleErrorStub, 'No alert notification channels exist.');
    
            console.error.restore();
        });
    
        it('throws no error when array returns is non-empty and has an item with the name property equal to `seamless-alerts`', async () => {
            clientStub.monitor.listNotificationChannels.resolves([
                { 
                    name: 'seamless-alerts' 
                }
            ]);
    
            const consoleErrorStub = sinon.stub(console, 'error');
    
            await checkAlertChannelsExist(clientStub);
    
            sinon.assert.notCalled(consoleErrorStub);
    
            console.error.restore();
        })
    });
});

