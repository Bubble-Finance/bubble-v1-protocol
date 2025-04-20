## [HIGH-04] Single point of failure via sole reliance on Pyth Network Oracles

### Status

Pending

### Severity (Impact x Probability): High (8)

Impact: High (4)
Probability: Low (2)

### Date created: 2025, Apr 19th

### Summary / PoC

The BubbleV1Raffle.sol contract relies exclusively on the Pyth Network for two critical external data feeds:

1. Randomness
2. Price Feeds

The addresses for both Pyth services (`i_pyth` and `i_entropy`) are declared immutable, meaning they are set in the constructor and cannot be changed after deployment without redeploying the entire contract. This architecture introduces a significant Single Point of Failure (SPoF) risk.

Failure, inaccuracy, censorship, or deprecation of the Pyth Network services used by the contract would have severe consequences:

1. Complete Stoppage of Raffle Entries
2. Permanent Stalling of Epoch Progression
3. Loss of Fairness due to Inaccuracy/Manipulation
4. Permanent Bricking due to Deprecation
5. Economic Viability Risk

### Recommendations

To mitigate the risks associated with a single oracle provider and immutable addresses, consider the following architectural improvements:

1. Implement oracle contracts upgradeability
2. Introduce oracle redundancy
3. Add emergency mechanisms in case of detected oracle malfunctions.
