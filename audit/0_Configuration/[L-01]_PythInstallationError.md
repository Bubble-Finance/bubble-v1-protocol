## [LOW-1] Pyth installation error

### Status : Pending

### Severity: N/A - Informational

Impact: N/A ; probability: N/A;

This case is special as only impact for development porpuse.

### Date created: 2025, Apr 07th

### Summary / PoC

The `make` file fails installing dependencies because the pyth instalation:

```
Error:
failed to resolve file: "/Users/aitor/repos_bubblefi/temp/bubble-v1-protocol/node_modules/@pythnetwork/pyth-sdk-solidity/PythStructs.sol": No such file or directory (os error 2); check configured remappings
	--> /Users/aitor/repos_bubblefi/temp/bubble-v1-protocol/src/library/BubbleV1Library.sol
	@pythnetwork/pyth-sdk-solidity/PythStructs.sol
make: *** [build] Error 1
```

### Recommendations

Added npm-install target in the `make` file:

- Explicitly installs the Pyth SDK via npm

- Called as part of the all target (runs after Foundry installs)

Check the lines added/modified:

```
start here ...

all:  remove install npm-install build     ** Here **

clean  :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install transmissions11/solmate --no-commit && forge install FastLane-Labs/atlas --no-commit

npm-install:; npm install @pythnetwork/pyth-sdk-solidity    ** Here **

... continue
```
