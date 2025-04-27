## [HIGH-07] Potential Re-entrancy via Unprotected Native Token Transfer

### Status

pending

### Severity (Impact x Probability): High (9)

Impact: 3
Probability: 3

### Date created: 2025, Apr 27th

### Summary / PoC

The internal function `_safeTransferNativeWithFallback` is used throughout the contract to send native currency to recipients. It employs the low-level `payable(address).call{value: amount}("")` method what it introduces a significant re-entrancy risk.

By default, `.call{value:}` forwards a large portion of the transaction's remaining gas. If the recipient (`_to`) is a malicious contract, it can use this gas to execute its `receive()` or `fallback()` function, which can include calls back into the `BubbleV1Campaigns` contract before the initial calling function has completed its execution and finalized all state changes.

While the contract attempts to mitigate this risk by generally applying the Checks-Effects-Interactions (CEI) pattern in functions like `collectFees`, `sellTokens`, and `buyTokens`, relying solely on CEI for re-entrancy protection with `.call{value:}` is fragile and considered unsafe practice:
It relies on the perfect application of CEI in all current and future code paths using this function.

The interaction sequence in more complex functions like `_completeBondingCurve` (which pays the creator reward using this function) involves multiple external calls and state changes, increasing the difficulty of ensuring re-entrancy safety through ordering alone.

It deviates from the widely accepted best practice of explicitly guarding against re-entrancy when using potentially unsafe low-level calls like `.call{value:}`.

### Recommendations

Implement a robust re-entrancy protection mechanism. The standard and strongly recommended approach is to use OpenZeppelin's ReentrancyGuard:
Inherit: Inherit ReentrancyGuard in the BubbleV1Campaigns contract:

```
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// ...
contract BubbleV1Campaigns is Owned, IBubbleV1Campaigns, ReentrancyGuard {
    // ...
}
```

Add the nonReentrant modifier to all public and external functions that perform state changes and eventually lead to external calls (including those using \_safeTransferNativeWithFallback). This includes, at minimum:

- collectFees
- createToken
- sellTokens
- buyTokens
