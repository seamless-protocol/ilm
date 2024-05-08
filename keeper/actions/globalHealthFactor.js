const { ethers } = require("ethers");
const { Defender } = require('@openzeppelin/defender-sdk');
const { isStrategyAtRisk } = require("./alerts");

const strategyABI = [
    "function debtUSD() external view returns (uint256)",
    "function collateralUSD() external view returns (uint256)",
];

// 0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e: 3x wstETH-ETH
// 0x2FB1bEa0a63F77eFa77619B903B2830b52eE78f4: 1.5x ETH-USDC
const strategyAddresses = ['0x258730e23cF2f25887Cb962d32Bd10b878ea8a4e', '0x2FB1bEa0a63F77eFa77619B903B2830b52eE78f4']
const healthFactorThreshold = ethers.BigNumber.from(ethers.utils.parseUnits('1.3', 8));
const BASE = ethers.BigNumber.from(ethers.utils.parseUnits('1.0', 8)); // value used for percentage calculations (1e8 == 100%)


exports.handler = async function (credentials, context) {
    const client = new Defender(credentials);

    const { notificationClient } = context;

    const provider = client.relaySigner.getProvider();
    const signer = client.relaySigner.getSigner(provider, { speed: 'fast' });
	
  	for (let strategyAddress of strategyAddresses) {
		let strategy = new ethers.Contract(strategyAddress, strategyABI, signer);
      
      	let { isAtRisk, threshold, healthFactor } = isStrategyAtRisk(strategy, healthFactorThreshold);

    	if (isAtRisk) {
        	try {
            	notificationClient.send({
                	channelAlias: 'seamless-alerts',
                	subject: 'HEALTH FACTOR THRESHOLD BREACHED',
                	message: `Current strategy health factor threshold is: ${threshold} and healthFactor is ${healthFactor} `,
            	});
        	} catch (error) {
            	console.error('Failed to send notification', error);
        	}
    	}
	}
}
