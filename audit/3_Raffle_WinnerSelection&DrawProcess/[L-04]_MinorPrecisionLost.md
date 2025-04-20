## [LOW-04] Minor Precision Loss in Prize Calculation Due to Integer Division

### Status

pending

### Severity: (Impact x Probability): Informatoional (16)

Impact: N/A ; probability: N/A;

### Date created 18TH OF APRIL 2025

### Summary / PoC

The `getWinnings` function calculates the prize amount for each supported token using standard Solidity integer arithmetic:

`winningAmount = (tokenBalance * winningPortion.numerator) / winningPortion.denominator;`

While the order of operations (multiplication before division) is correctly implemented to minimize precision loss within standard integer math, the final division operation inherently truncates any fractional part of the result.

If the calculated prize share (tokenBalance \* winningPortion.numerator) is less than the denominator (winningPortion.denominator), the result of the integer division will be zero.

** check!!! not sure **

1. Epoch N=5 has concluded.
2. Alice is claiming Tier 3 winnings (winningPortion has numerator = 5, denominator = 100, representing 5%).
3. For TOKEN_X, the total amount collected in the epoch is small:
   `s_epochToTokenAmountsCollected[5][TOKEN_X] = tokenBalance = 19`. (like 0,000000...19).
4. Calculation in getWinnings:
   `winningAmount = (tokenBalance * winningPortion.numerator) / winningPortion.denominator`
   `winningAmount = (19 * 5) / 100`
   `winningAmount = 95 / 100`
5. Using integer division: winningAmount = 0.

Although Alice was technically entitled to 0.95 base units of TOKEN_X, the calculation results in 0, and she receives nothing for TOKEN_X. The 19 units remain in the contract (potentially pooled with other Tier 3 winnings for that token).

### Recommendations

This issue could be considered an acceptable trade-off for gas efficiency and code simplicity.

We can:

1. Accepted
2. use Solmate `FixedPointMathLib` which handle fractional values internally.
