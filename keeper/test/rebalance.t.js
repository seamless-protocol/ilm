const { expect } = require('chai');
const sinon = require('sinon');
const { performRebalance } = require('../actions/rebalance'); 

describe('performRebalance', () => {
    let strategyStub;

    beforeEach(() => {
        strategyStub = {
            rebalanceNeeded: sinon.stub(),
            rebalance: sinon.stub()
        };
    });
    
    afterEach(() => {
        sinon.restore();
    });

    it('should call rebalance if rebalanceNeeded returns true', async () => {
      strategyStub.rebalanceNeeded.resolves(true);
      strategyStub.rebalance.resolves({hash: 'txHash'});

      const result = await performRebalance(strategyStub);

      // assert that rebalanceNeeded was called
      sinon.assert.calledOnce(strategyStub.rebalanceNeeded);

      // assert that rebalance was called
      sinon.assert.calledOnce(strategyStub.rebalance);

      // Assert that correct transaction hash is returned
      expect(result).to.deep.equal({ tx: 'txHash' });
    });

    it('should not call rebalance if rebalanceNeeded returns false', async () => {
    strategyStub.rebalanceNeeded.resolves(false);
    
    // call the performRebalance with stubs
    const result = await performRebalance(strategyStub);

    // assert that rebalanceNeeded was called
    sinon.assert.calledOnce(strategyStub.rebalanceNeeded);

    // assert that rebalance was not called
    sinon.assert.notCalled(strategyStub.rebalance);

    // assert that result is undefined
    expect(result).to.be.undefined;
    });

    it('should handle errors', async () => {
        strategyStub.rebalanceNeeded.rejects(new Error('error thrown'));
        const consoleErrorStub = sinon.stub(console, 'error');
        
        await performRebalance(strategyStub);
        
        sinon.assert.calledOnce(consoleErrorStub);
        expect(consoleErrorStub.firstCall.args[0]).to.include('An error occurred on rebalance call:');
        
        console.error.restore();
    });
});

