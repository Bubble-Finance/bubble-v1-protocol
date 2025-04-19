## [HIGH-03] Denial of Service (DoS) in `claimTierWinnings` via Unbounded Loop

### Status

Pending

### Severity (Impact x Probability): High (12)

Impact: High (4)
Probability: Medium (3)

### Date created: 2025, Apr 19th

### Summary / PoC

The `claimTierWinnings` function, which is essential for winners to receive their raffle prizes, relies on iterating through the entire list of `s_supportedTokens` multiple times implicitly and explicitly. First, it calls the `getWinnings` view function, which loops through all supported tokens at least once (to fetch balances) and potentially multiple times within a nested loop (to calculate winnings if the NFT range is hit by multiple random numbers for the tier). Second, after `getWinnings` returns, `claimTierWinnings` itself loops through the list of supported tokens again to perform the actual `safeTransfer` calls for the prize distribution.

The number of supported tokens (`s_supportedTokens`) is controlled by `Owner` via the `supportToken()` function and has no hardcoded upper limit. As the number of supported tokens increases, the gas cost associated with the multiple loops within `getWinnings` and `claimTierWinnings` scales linearly (or slightly worse due to nesting and external calls). If a large number of tokens are supported, the total gas required to execute `claimTierWinnings` can easily exceed the block gas limit.

As the total number of supported tokens is controlled by the Owner, it can be maintain under control which set the probability to medium, but it is still a major issue.

**_ <<< POC PENDING >>>> _**

### Recommendations

Redesign the claiming process to allow users to claim winnings for a subset of supported tokens per transaction.

**_ create the code _**
