## [CRITICAL-01] Potential Reentrancy vulnerability due to missing standard guard

### Status

Pending

### Severity (Impact x Probability): Critical (16)

Impact: Very High (4)
Probability: High (4)

### Date created: 2025, Apr 17th

### Summary / PoC

The BubbleV1Pool contract implements a custom mutex lock, `globalLock()` modifier using the s_isLocked boolean, intended to prevent reentrancy attacks in core functions like addLiquidity, removeLiquidity, and swap.

While this custom lock provides basic protection against simple recursive calls, it presents weaknesses compared to industry best practices:

1. Lack of Standard Guard: It does not use the widely adopted, heavily audited, and battle-tested ReentrancyGuard from OpenZeppelin, potentially missing subtle edge cases covered by the standard implementation.
2. Confusing Lock States: The `s_isLocked` variable is used for both temporary reentrancy protection during function execution and for the owner-controlled permanent locking (lockPool/unlockPool), reducing code clarity and making state reasoning more complex.

### Recommendations

1. Replace the custom globalLock logic for temporary execution locking with OpenZeppelin's ReentrancyGuard. Inherit the guard and apply the nonReentrant modifier to all functions susceptible to reentrancy (addLiquidity, removeLiquidity, swap).
2. Design the `s_isLocked` solution by something clearer like `s_isTemporaryLocked` and `_isPermanentlyLocked` and use it only for the temporary/permanent locking mechanism of the group controlled by the owner other than the nonReentrant modifier.
