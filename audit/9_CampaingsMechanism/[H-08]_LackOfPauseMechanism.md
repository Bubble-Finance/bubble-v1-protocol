## [HIGH-08] Absence of Emergency Pause Mechanism

### Status

pending

### Severity (Impact x Probability): High (9)

Impact: 3
Probability: 3

### Date created: 2025, Apr 26th

### Summary / PoC

The `BubbleV1Campaigns` contract lacks a mechanism to pause critical functionalities in case of an emergency. There are no functions allowing the owner (or a designated security role) to temporarily halt state-changing operations such as creating new tokens (`createToken`), buying tokens (`buyTokens`), or selling tokens (`sellTokens`).

In the event that a critical vulnerability, exploit, or severe misconfiguration is discovered post-deployment, the absence of a pause capability prevents administrators from immediately stopping interactions with the vulnerable contract functions.

1. Attackers can continue to exploit a discovered vulnerability, potentially draining funds from active campaigns or extracting protocol fees until a fix can be deployed (which often requires time for development, testing, and potentially governance or timelock delays).
2. The window for potential financial loss is extended, as administrators cannot instantly prevent further interactions that could lead to theft or value loss for users or the protocol.
3. Responding to an incident becomes more difficult and potentially chaotic without the ability to safely halt operations, investigate the issue, and coordinate a response or upgrade.
4. Failure to quickly contain an ongoing exploit due to the lack of basic safety mechanisms like pausing can severely damage user trust and the protocol's reputation.

### Recommendations

Implement a pause mechanism using industry-standard practices, such as OpenZeppelin's Pausable contract:

```
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
// ...
contract BubbleV1Campaigns is Owned, IBubbleV1Campaigns, ReentrancyGuard /* If added */, Pausable {
    // ...
}
```

The `pause()` and `unpause()` functions will be controlled by the owner by default when used alongside Owned (from Solmate). Ensure this access control aligns with the desired security model.

Add the `whenNotPaused` modifier to all critical public/external functions that should be halted during an emergency. This should include, at minimum:

- `createToken`
- `buyTokens`
- `sellTokens`

Consider if other state-changing functions (e.g., collectFees, administrative set... functions) should also be pausable depending on the desired level of control during an incident.

Call the `_pause()` internal function in the constructor if the contract should start in a paused state, or ensure it starts unpaused as needed.
