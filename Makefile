all:  remove install build

clean  :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install transmissions11/solmate --no-commit

update:; forge update

compile:; forge compile

build:; forge build

test :; forge test

format :; forge fmt

precommit :; forge fmt && git add .

snapshot :; forge snapshot

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deployLocal :; forge script script/DeployProtocol.s.sol:DeployProtocol --broadcast --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

anvilBaseSepoliaFork :; anvil --fork-url https://sepolia.base.org

deployOnBaseSepoliaFork :; forge script script/DeployProtocol.s.sol:DeployProtocol --broadcast --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80