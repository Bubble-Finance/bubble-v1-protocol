## [M-1] Potential DOS by address greifing in the `deployPool` function.

### Status 

pending

### Severity (Impact x Probability) Medium 

Impact: 4
properbility: 2

### Date created: 4th of April 2025

### Summary / PoC
In the `BubbleV1Factory.sol` contract, there is a possibe DOS caused by address-greifing in the `deployPool` contract. the function takes uses create2 opcode to create `newPoolAddress`, this var is used to create
new pool for trading between two token. the problem comes here, any malicious user because of this deterministic can determine the can predict the exact address where the new pool will be deployed.

**_ <<< POC PENDING >>>> _**
### Recommendations
consider adding a nonce check or msg.sender to the salt.