
const withdrawSig = 'Withdraw(address,address,address,uint256,uint256)';
const priceUpdateSig = 'AnswerUpdated(int256,uint256,uint256)';

exports.handler = async function (payload) {
    const conditionRequest = payload.request.body;
    const matches = [];
    const events = conditionRequest.events;
    for (let evt of events) {
        if(evt.matchReasons.signature == withdrawSig) {
            matches.push({
                hash: evt.hash,
                metadata: {
                    "notificationType": "withdrawal",
                    "strategy": evt.matchedChecksumAddress
                }
             });
        }

        if(evt.matchReasons.signature == priceUpdateSig) {
            matches.push({
                hash: evt.hash,
                metadata: {
                    "notificationType": "priceUpdate",
                    "oracle": evt.matchedChecksumAddress
                }
            })
        }
    }
    return { matches }
}

