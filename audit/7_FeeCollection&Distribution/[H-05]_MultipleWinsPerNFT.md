## [HIGH-05] Multiple Wins Per NFT Per Tier Due to Incorrect Prize Calculation

### Status

Pending

### Severity (Impact x Probability): High (8)

Impact: High (4)
Probability: Medium (2)

### Date created: 2025, Apr 20th

### Summary / PoC

The `getWinnings` function calculates the prizes for a specific NFT (`_claim.tokenId`), epoch (`_claim.epoch`), and tier (`_claim.tier`). It iterates through the set of random numbers assigned to that tier (e.g., 1 number for Tier 1, 2 numbers for Tier 2, 3 numbers for Tier 3). For each random number in the set, it checks if the derived hitPoint falls within the NFT's designated range (`nftToRange`). If it does, the function immediately adds the calculated prize portion (`winningAmount`) for that tier to the winnings accumulator for that NFT.

The critical flaw is that this addition (+=) occurs inside the loop iterating through the tier's random numbers. If multiple random numbers assigned to the same tier happen to generate hitPoints that fall within the same NFT's range, that single NFT will have the prize portion added to its total winnings multiple times within a single getWinnings call for that tier.

This contradicts the likely intended logic implied by the constants `WINNERS_IN_TIER_1`, `WINNERS_IN_TIER_2`, and `WINNERS_IN_TIER_3`, which suggest selecting a fixed number of distinct winners for each tier.

This vulnerability leads to several negative consequences:

1.  A single NFT can win significantly more than its fair share for a given tier.
2.  If one NFT claims multiple "winner slots" within a tier, it effectively reduces the number of unique winners, potentially excluding other participants who should have won.
3.  The raffle may produce fewer unique winning addresses than suggested that could lead to a erosion of trust in the protocol.

** PoC pending **

### Recommendations

Modify the `getWinnings` logic to ensure that an NFT receives the prize portion for a tier at most once, regardless of how many random numbers assigned to that tier hit its range. The standard approach is to check if any hit occurred and then assign the prize once.

1. Introduce a Hit Flag: Use a boolean flag to track if any random number for the tier hit the NFT's range.
2. Separate Hit Check from Prize Calculation: Perform the prize calculation and addition after checking all random numbers for the tier, conditional on the flag being set.

** pending code **
