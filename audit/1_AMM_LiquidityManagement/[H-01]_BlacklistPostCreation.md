## [H-01] Existing Pools unaffected by token blacklisting

### Status

Pending

### Severity (Impact x Probability): High (9)

Impact: High (3)
Probability: Medium (3)

### Date created: 2025, Apr 15th

### Summary / PoC

While the `BubbleV1Router` correctly prevents interactions with pools containing tokens blacklisted in the BubbleV1Factory (by checking token support during pool/reserve lookups), users or contracts interacting directly with a `BubbleV1Pool` contract can bypass these checks.

Functions like addLiquidity, removeLiquidity, and swap on the pool itself do not consult the factory's blacklist. The user who has deployed his malicious tokens could, in this way, remove them without penalty and cause reputational damage to the protocol.

**_ <<< POC PENDING >>>> _**

### Recommendations

Consider adding a check within the BubbleV1Pool's globalLock modifier or at the start of its core functions to query the factory's isSupportedToken status for s_tokenA and s_tokenB.

**_ create the code _**
