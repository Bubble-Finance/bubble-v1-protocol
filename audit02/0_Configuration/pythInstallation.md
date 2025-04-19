## [I-1] In the Makefile, There is an absent of pyth installation.

### Status pending 

### Severity: [N/A] Informational

### Date created: 4th of april 2025
### Summary / PoC
The makefile lacks an installation of pyth oracle library, using `forge install` install all other neccassary dependencies, OZ, forge-std, soulmate, etc. but lacks the installation of pythnetwork/client. 

### Recommendations
1. add the following line to makefile.
  
```diff
    install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit && forge install transmissions11/solmate --no-commit && forge install FastLane-Labs/atlas --no-commit && forge install pythnetwork/pyth-sdk-solidity --no-commit

+   pythInstall :; npm i @pythnetwork/client
```
2. add the following to ReadMe.md
```diff
+   ```shell
+   make pythInstall
+   ```
```
