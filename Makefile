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
deploy-wrappedwstETH-base-mainnet 		:; forge script deploy/mainnet/DeployWrappedwstETH.s.sol --tc DeployWrappedwstETH --force --rpc-url ${BASE_MAINNET_RPC_URL} --slow --broadcast --verify --delay 5 --verifier-url ${VERIFIER_URL} -vvvv
deploy-wrappedwstETH-fork 						:; forge script deploy/mainnet/DeployWrappedwstETH.s.sol --tc DeployWrappedwstETH --force --rpc-url ${FORK_RPC} --slow --broadcast --delay 5 -vvvv