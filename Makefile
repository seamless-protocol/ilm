# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

.PHONY: test clean

# Build & test
build                   :; forge build
coverage                :; forge coverage
gas                     :; forge test --gas-report
gas-check               :; forge snapshot --check --tolerance 1
snapshot                :; forge snapshot
clean                   :; forge clean
fmt                     :; forge fmt
test                    :; forge test -vvv --no-match-test test_e2eSimulation --gas-report && forge test -vvv --mt test_e2eSimulation

# Deploy
deploy-wrappedwstETH-base-mainnet 								:; forge script script/deploy/base-mainnet/DeployWrappedwstETH.s.sol --tc DeployWrappedwstETH --force --rpc-url base --chain base --slow --broadcast --verify --delay 5 -vvvv
deploy-wrappedwstETH-tenderly 										:; forge script script/deploy/base-mainnet/DeployWrappedwstETH.s.sol --tc DeployWrappedwstETH --force --rpc-url tenderly --slow --broadcast -vvvv --verify --verifier-url ${TENDERLY_FORK_VERIFIER_URL} --etherscan-api-key ${TENDERLY_ACCESS_KEY}

deploy-loopStrategyWstETHoverETH-base-mainnet 		:; forge script script/deploy/base-mainnet/DeployLoopStrategyWstETHoverETH.s.sol --tc DeployLoopStrategyWstETHoverETH --force --rpc-url base --chain base --slow --broadcast --verify --delay 5 -vvvv
deploy-loopStrategyWstETHoverETH-tenderly 				:; forge script script/deploy/base-mainnet/DeployLoopStrategyWstETHoverETH.s.sol --tc DeployLoopStrategyWstETHoverETH --force --rpc-url tenderly --slow --broadcast -vvvv --verify --verifier-url ${TENDERLY_FORK_VERIFIER_URL} --etherscan-api-key ${TENDERLY_ACCESS_KEY}

deploy-loopStrategyImplementation-base-mainnet		:; forge script script/deploy/DeployLoopStrategyImplementation.s.sol --tc DeployLoopStrategyImplementation --force --rpc-url base --chain base --slow --broadcast --verify --delay 5 -vvvv
deploy-loopStrategyImplementation-tenderly		    :; forge script script/deploy/DeployLoopStrategyImplementation.s.sol --tc DeployLoopStrategyImplementation --force --rpc-url tenderly --slow --broadcast -vvvv --verify --verifier-url ${TENDERLY_FORK_VERIFIER_URL} --etherscan-api-key ${TENDERLY_ACCESS_KEY}

deploy-swapperImplementation-base-mainnet					:; forge script script/deploy/DeploySwapperImplementation.s.sol --tc DeploySwapperImplementation --force --rpc-url base  --chain base --slow --broadcast --verify --delay 5 -vvvv
deploy-swapperImplementation-tenderly		    			:; forge script script/deploy/DeploySwapperImplementation.s.sol --tc DeploySwapperImplementation --force --rpc-url tenderly --slow --broadcast -vvvv --verify --verifier-url ${TENDERLY_FORK_VERIFIER_URL} --etherscan-api-key ${TENDERLY_ACCESS_KEY}

deploy-wrappedWETH-base-mainnet 								:; forge script script/deploy/base-mainnet/DeployWrappedWETH.s.sol --tc DeployWrappedWETH --force --rpc-url base --chain base --slow --broadcast --verify --delay 5 -vvvv
deploy-wrappedWETH-tenderly 										:; forge script script/deploy/base-mainnet/DeployWrappedWETH.s.sol --tc DeployWrappedWETH --force --rpc-url tenderly --slow --broadcast -vvvv --verify --verifier-url ${TENDERLY_FORK_VERIFIER_URL} --etherscan-api-key ${TENDERLY_ACCESS_KEY}
