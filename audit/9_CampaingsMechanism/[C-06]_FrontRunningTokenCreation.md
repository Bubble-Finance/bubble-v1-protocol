## [CRITICAL-06] Token Creation Parameters Susceptible to Front-running (MEV)

### Status

pending

### Severity (Impact x Probability): High (16)

Impact: 4
Probability: 4

### Date created: 2025, Apr 26th

### Summary / PoC

The `createToken()` function allows any user to deploy a new ERC20Launchable token and initiate its bonding curve campaign by providing token details `_tokenDetails` and an initial purchase amount `_initialNativeAmountToBuyWith`.

As transaction data, including function parameters, is publicly visible in the mempool before execution, this creates an opportunity for Miner Extractable Value (MEV) bots or malicious actors. An attacker can observe a pending createToken transaction, copy the exact parameters (token name, symbol, supply, bonding curve settings), and submit their own identical createToken transaction with a higher gas price. This front-running transaction will likely be mined first, causing the attacker's token to be created before the original user's token.

While this attack does not directly steal funds from the original user during the createToken call itself, the consequences are severe:

1. Duplicate Token Creation.
2. Campaign Dilution & Failure:
3. Reputational Damage:

### Recommendations

Implement a mechanism to prevent or mitigate this form of front-running on token creation. The most robust solution is a Commit-Reveal Scheme:

1.  Commit Phase: Introduce a new function where users submit a hash of their intended `_tokenDetails` and other parameters (
    e.g., `keccak256(abi.encode(_tokenDetails, salt))`).
    This transaction commits their intent without revealing the actual parameters.
2.  Reveal Phase: Introduce a modified createToken function (or a new reveal function) where the user submits the actual \_tokenDetails and the salt used in the commit phase. The contract verifies that the hash of the revealed parameters matches the previously committed hash before proceeding with token creation.
