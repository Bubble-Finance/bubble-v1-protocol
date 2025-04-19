## [MEDIUM-02] Late raffle entries possible after draw initiation

### Status

Pending

### Severity (Impact x Probability): Medium (6)

Impact: Medium (2)
Probability: Medium (3)

### Date created: 2025, Apr 19th

### Summary / PoC

The `BubbleV1Raffle.sol` contract allows users to enter the current raffle epoch (s_epoch) even after the process to determine the winners for that epoch has been initiated via a call to requestRandomNumber. There is a time window between the successful execution of `requestRandomNumber` (which sends a request for a random number to the Pyth Entropy oracle) and the execution of the subsequent `entropyCallback` function (where the random number is received and the epoch is formally concluded).

During this window, the enterRaffle function does not prevent new entries from being added to the epoch whose draw is already in progress.

This creates a slight mismatch and fairness issue. The prize pool includes the late contribution, but the probability distribution based on the random number and the final range is slightly skewed compared to the state when the draw was initiated. It benefits the late entrant (they get a chance to win prizes they contributed to) but slightly dilutes the chances of everyone else who entered before `requestRandomNumber` was called. It doesn't seem like a way to guarantee a win, but it does alter the expected probabilities based on the state at the intended draw time.

**_ <<< POC PENDING >>>> _**

### Recommendations

To ensure epoch integrity and prevent entries after the draw process has started, implement a mechanism to lock entries for the current epoch once requestRandomNumber has been successfully executed.

Introduce a State Variable: Add a mapping to track if the randomness request for an epoch has been initiated:

`mapping(uint256 epoch => bool) private s_isRandomnessRequested;`

**_ create the code _**
