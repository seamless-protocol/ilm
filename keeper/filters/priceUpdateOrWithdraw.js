
const withdrawSig = 'Withdraw(address,address,address,uint256,uint256)';
const priceUpdateSig = 'AnswerUpdated(int256,uint256,uint256)';

exports.handler = async function(payload) {
    const conditionRequest = payload.request.body;
    const matches = [];
    const events = conditionRequest.events;
    for(const evt of events) {
      if (evt.eventSignature == priceUpdateSig || evt.eventSignature == withdrawSig) {
        let notificationType = evt.eventSignature === priceUpdateSig ? 'priceUpdate' : 'withdarwal';
        
        matches.push({
            hash: evt.hash,
            metadata: {
             "type": notificationType,
            }
         });
      }
    }
    return { matches }
  }

