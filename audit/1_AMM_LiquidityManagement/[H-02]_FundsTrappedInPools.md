## [HIGH-02] Funds can be permanently trapped in Locked Pools

### Status

Pending

### Severity (Impact x Probability): High (9)

Impact: High (3)
Probability: Medium (3)

### Date created: 2025, Apr 15th

### Summary / PoC

The `BubbleV1Factory` contract grants the owner the ability to lock any `BubbleV1Pool` instance via the `lockPool` function. This action sets an internal `s_isLocked` flag within the target pool to true.

The core functions for user interaction within the pool (addLiquidity, removeLiquidity, swap, etc.) are protected by the globalLock modifier, which reverts the transaction if `s_isLocked` is true. Critically, the `removeLiquidity` function, which is the standard mechanism for Liquidity Providers (LPs) to withdraw their deposited tokens, is also blocked by this modifier.

If the owner locks a pool, there is no alternative mechanism within the protocol for LPs to recover their underlying tokenA and tokenB assets, except unlocked with the consequent risk. This is a major problem, as it could leave LP funds within any pool frozen indefinitely.

**_ <<< POC PENDING >>>> _**

### Recommendations

Consider adding a check within the BubbleV1Pool's globalLock modifier or at the start of its core functions to query the factory's isSupportedToken status for s_tokenA and s_tokenB.

**_ create the code _**
