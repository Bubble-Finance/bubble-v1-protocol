## [LOW-03] getAllPools Function Susceptible to Block Gas Limit Denial of Service (DoS).

** Review Poc and recommendations in audit2 **

### Status : Pending

### Severity: Low (2)

Impact: Low (1)
probability: Low (2)

### Date created: 2025, Apr 16th

### Summary / PoC

The `BubbleV1Factory` contract maintains a dynamically sized array `s_allPool`s which stores the address of every pool deployed. The external view function `getAllPools()` returns this entire array.

Reading and returning dynamic arrays consumes gas proportional to the number of elements. If the protocol becomes highly successful and hosts a vast number of trading pools, the gas cost associated with calling `getAllPools()` could eventually exceed the Ethereum block gas limit.

This would cause any on-chain transaction attempting to call this function to fail, effectively resulting in a Denial of Service for that specific function call.

### Recommendations

Implement Paginated Getter

```
function getPoolsSlice(uint256 _start, uint256 _count) ....

blablabla --- PENDING


```
