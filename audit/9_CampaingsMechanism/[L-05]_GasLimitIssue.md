## [LOW-05] Potential Out-of-Gas Failure During Campaign Completion

### Status

pending

### Severity (Impact x Probability): Low (4)

Impact: 2
Probability: 2

### Date created: 2025, Apr 27th

### Summary / PoC

The internal function `_completeBondingCurve` is executed within the same transaction as the final `buyTokens` call that meets the campaign's target native token reserve. This function performs a sequence of relatively gas-intensive operations:

1. Approving the router to spend the launchpad token.
2. Calling `addLiquidityNative` on the `BubbleV1Router`, which involves creating a pool (if new), transferring both native currency and the token, minting LP tokens, and associated storage updates.
3. Transferring the native token creator reward via `_safeTransferNativeWithFallback` (which may involve a WNative deposit and transfer if the initial call fails).
4. Updating internal state variables (`s_feeCollected`, `s_tokenDetails[_token].launched`).
5. Calling `launch()` on the `ERC20Launchable` token contract.
6. Calling `transferOwnership()` on the `ERC20Launchable` token contract.

Bundling all these operations into a single transaction creates a risk that the total gas consumed could exceed the blockchain's block gas limit.

Impact:

If the transaction executing the final `buyToken`s call and subsequently `_completeBondingCurve` fails due to running out of gas.

The campaign becomes stuck in its final state, unable to achieve its primary goal of launching the token and seeding liquidity, potentially requiring manual intervention or leaving the campaign in a permanently unfinished state.

### Recommendations

To mitigate the risk of exceeding the block gas limit, consider decoupling the campaign completion logic from the token purchase transaction:

1. Modify buyTokens: When the purchase meets or exceeds the target reserve, the function should update the token/native reserves, record the purchase, mark the campaign as "ready for completion" (e.g., setting a new flag in TokenDetails), but not call `_completeBondingCurve` directly.
2. Introduce a new external function, e.g., `finalizeCampaign(address)`. This function would check if the campaign is marked "ready for completion" and then execute the logic currently in `_completeBondingCurve`. This function could potentially be permissionless (callable by anyone) or restricted (e.g., callable only by the creator or owner).

This separates the gas costs into two distinct transactions, significantly reducing the chance of hitting the block gas limit in a single transaction.
