-include .env

all:  remove install build

clean  :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install transmissions11/solmate --no-commit && forge install FastLane-Labs/atlas --no-commit

update:; forge update

compile:; forge compile

build:; forge build

test :; forge test

format :; forge fmt

snapshot :; forge snapshot

precommit :; forge fmt && git add .

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy-protocol-without-governance-local :; forge script script/DeployProtocolWithoutGovernance.s.sol \
	--broadcast \
	--rpc-url 127.0.0.1:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

attach-governance-local :; forge script script/AttachGovernance.s.sol \
	--broadcast \
	--rpc-url 127.0.0.1:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

deploy-campaigns-local :; forge script script/DeployCampaigns.s.sol \
	--broadcast \
	--rpc-url 127.0.0.1:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

deploy-protocol-without-governance-on-chain :; forge script script/DeployProtocolWithoutGovernance.s.sol \
	--broadcast \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY) \
	--verify --verifier-url $(VERIFIER_URL) --etherscan-api-key $(ETHERSCAN_API_KEY)

attach-governance-on-chain :; forge script script/AttachGovernance.s.sol \
	--broadcast \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY) \
	--verify --verifier-url $(VERIFIER_URL) --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-campaigns-on-chain :; forge script script/DeployCampaigns.s.sol \
	--broadcast \
	--rpc-url $(RPC_URL) \
	--private-key $(PRIVATE_KEY) \
	--verify --verifier-url $(VERIFIER_URL) --etherscan-api-key $(ETHERSCAN_API_KEY)
