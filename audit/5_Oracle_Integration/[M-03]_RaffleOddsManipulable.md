## [MEDIUM-03] Raffle odds can be manipulated by outdated or volatile Oracle prices.

### Status

Pending

### Severity (Impact x Probability): Medium (6)

Impact: Medium (2)
Probability: High (3)

### Date created: 2025, Apr 20th

### Summary / PoC

The enterRaffle function determines a user's chance of winning (represented by the distance added to their NFT's range) based on the USD value of their contributed tokens (minus fees). This USD value is calculated by the `_convertToUsd` function, which queries the Pyth Network oracle using `IPyth(i_pyth).getPriceNoOlderThan(config.priceFeedId, config.noOlderThan)`.

The vulnerability lies in the potential for the price returned by the oracle at the time of the enterRaffle call to significantly differ from the true, current market price.

On the other hand, a user can benefit from a token with a very volatile value to enter at the most appropriate time and take more tickets than he is entitled to.

### Recommendations

To mitigate the first:

1. The contract owner must configure `noOlderThan` with very small, conservative values.
2. Modify \_convertToUsd to perform an additional check against `block.timestamp`, independent of the configured `noOlderThan`.

Also..

1. Oracle Redundancy -> integrate a second oracle provider (like Chainlink) and using aggregated/median prices.
