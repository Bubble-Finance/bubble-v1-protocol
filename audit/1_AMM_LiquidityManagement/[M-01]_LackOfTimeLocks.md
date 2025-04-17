## [MEDIUM-01] Critical parameter changes (fees, blacklists) are immediate.

### Status : Pending

### Severity: Medium (6)

Impact: High (3)
probability: Low (2)

### Date created: 2025, Apr 13th

### Summary / PoC

Affected Contracts: `BubbleV1Factory.sol` - `BubbleV1Pool.sol`

The protocol allows privileged roles (owner, protocol team multisig) to immediately modify critical parameters (e.g., fee tiers, token blacklists, protocol fees) without a timelock. This introduces centralization risks, as sudden changes could disrupt user strategies or lead to governance attacks if privileged keys are compromised.

1. Frontrunning Users:

   - A malicious/compromised owner observes a large pending swap or liquidity event.

   - They frontrun it by increasing the pool’s fee tier, extracting excess value.

2. Sudden Blacklisting:

   - Legitimate tokens can be frozen without warning, trapping user funds.

### Recommendations

Once the governance module is deployed, the protocol has its own timelocker, but in the meantime, it is recommended to place it in the functions themselves:

1. To warn of a change of fees that will occur after X days.
2. To block a pool for a certain number of days, indicating when it will be unblocked or when the removal of the pool and the distribution of funds will be definitive.

Example of timeLock:

```
uint256 public constant TIMELOCK_DURATION = 2 days;

blablabla --- PENDING


```
