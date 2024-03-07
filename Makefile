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
test                    :; forge test -vvvv --gas-report

# Deploy
deploy-wrappedwstETH-base-mainnet 		:; forge script script/deploy/base-mainnet/DeployWrappedwstETH.s.sol --tc DeployWrappedwstETH --force --rpc-url ${BASE_MAINNET_RPC_URL} --slow --broadcast --verify --delay 5 --verifier-url ${VERIFIER_URL} -vvvv
deploy-wrappedwstETH-fork 						:; forge script script/deploy/base-mainnet/DeployWrappedwstETH.s.sol --tc DeployWrappedwstETH --force --rpc-url ${FORK_RPC} --slow --broadcast -vvvv

deploy-loopStrategyWstETHoverETH-base-mainnet 		:; forge script script/deploy/base-mainnet/DeployLoopStrategyWstETHoverETH.s.sol --tc DeployLoopStrategyWstETHoverETH --force --rpc-url ${BASE_MAINNET_RPC_URL} --slow --broadcast --verify --delay 5 --verifier-url ${VERIFIER_URL} -vvvv
deploy-loopStrategyWstETHoverETH-fork 						:; forge script script/deploy/base-mainnet/DeployLoopStrategyWstETHoverETH.s.sol --tc DeployLoopStrategyWstETHoverETH --force --rpc-url ${FORK_RPC} --slow --broadcast -vvvv

deploy-loopStrategyImplementation-base-mainnet		:; forge script script/deploy/DeployLoopStrategyImplementation.s.sol --tc DeployLoopStrategyImplementation --force --rpc-url ${BASE_MAINNET_RPC_URL} --slow --broadcast --verify --delay 5 --verifier-url  ${VERIFIER_URL} -vvvv
deploy-loopStrategyImplementation-fork		:; forge script script/deploy/DeployLoopStrategyImplementation.s.sol --tc DeployLoopStrategyImplementation --force --rpc-url ${FORK_RPC} --slow --broadcast --verify --delay 5 --verifier-url  ${VERIFIER_URL} -vvvv