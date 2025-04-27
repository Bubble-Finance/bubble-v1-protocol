## [MEDIUM-05] No Mechanism to Handle Failed or Stalled Campaigns, Risking User Funds

### Status

pending

### Severity (Impact x Probability): Medium (6)

Impact: 2
Probability: 3

### Date created: 2025, Apr 27th

### Summary / PoC

The BubbleV1Campaigns contract facilitates token launches via bonding curves, aiming to reach a specific `targetNativeTokenReserve`. However, there is no mechanism within the contract to define or handle the scenario where a campaign fails to reach this target, potentially indefinitely. The contract lacks a deadline or time limit for campaigns.

Currently, if a campaign stalls or fails to attract sufficient investment to reach its target:

1. The `_completeBondingCurve` function is never triggered.
2. The associated `ERC20Launchable` token remains restricted, preventing free trading or listing on external markets.

Users holding the launchpad token can only attempt to recover their investment by using the sellTokens function, exchanging their tokens back for native currency based on the curve's current reserve ratio.

The critical issue arises if early buyers or speculators sell their tokens back to the curve, draining the `nativeTokenReserve` associated with that specific campaign. If this reserve is significantly depleted or reduced to zero, subsequent token holders calling sellTokens will receive very little or no native currency in return, effectively making their tokens worthless within the context of the BubbleV1Campaigns contract. The contract provides no alternative recourse in this situation.

Users who invest in campaigns that ultimately fail to reach their funding goal and subsequently see the campaign's native liquidity drained by sellers risk losing their entire investment. The launchpad tokens they hold become illiquid and potentially valueless, as there is no defined mechanism for campaign failure resolution, such as a deadline-triggered refund or proportional distribution of remaining reserves. This creates a poor user experience and potential for significant financial loss in unsuccessful launches.

### Recommendations

Implement mechanisms to handle failed or stalled campaigns gracefully and provide a safety net for participants:

1. Campaign Deadline: Introduce a mandatory `campaignEndTime` (Unix timestamp) parameter during token creation (`createToken`). This defines a clear end date for the fundraising period.
2. Failure State: If `block.timestamp > campaignEndTime` and the campaign's launched status is still false (meaning the target was not met), the campaign should enter a "failed" state. Buying (`buyTokens`) and potentially selling (`sellTokens` via the curve) should be disabled in this state.
3. Refund Mechanism: Introduce a new external function, such as `claimRefundFailedCampaign(address _token)`. This function should:
   - Verify that the campaign associated with `_token` is in the "failed" state (`block.timestamp > campaignEndTime` and `!launched`).
   - Allow users to burn their holdings of the specific launchpad token (`_token`).
   - In return, distribute a pro-rata share of the remaining `nativeTokenReserve` held by the contract for that specific campaign, based on the percentage of the total remaining token supply the user is burning.
   - Ensure users cannot claim refunds multiple times.
