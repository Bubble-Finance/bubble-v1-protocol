### Note: Check for Reentrancy in Swap Functionality

Ensure that the swap functionality is protected against reentrancy attacks. Verify the use of appropriate reentrancy guards (e.g., `nonReentrant` modifier) and review the order of external calls and state updates to prevent potential vulnerabilities.

for example no CEI pattern

1 Interact

```
if (_swapParams.amountAOut > 0) {
                IERC20(s_tokenA).safeTransfer(_swapParams.receiver, _swapParams.amountAOut);
            }
            if (_swapParams.amountBOut > 0) {
                IERC20(s_tokenB).safeTransfer(_swapParams.receiver, _swapParams.amountBOut);
            }
```

2. Check
   balanceA = IERC20(s_tokenA).balanceOf(address(this));
   balanceB = IERC20(s_tokenB).balanceOf(address(this));

3. Effect
   updateReservesAndTWAP(balanceA, balanceB, reserveA, reserveB);
