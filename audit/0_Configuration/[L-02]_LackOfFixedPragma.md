## [LOW-01] Lack of Fixed Pragma Version

### Status : Pending

### Severity: N/A - Informational

Impact: N/A ; probability: N/A;

This case is special as only impact for development porpuse.

### Date created: 2025, Apr 13th

### Summary / PoC

The Solidity contracts within the BubbleFi v1 protocol predominantly use a floating pragma version specification, such as pragma solidity ^0.8.25;. The caret (^) symbol allows the contract to be compiled by any compiler version from 0.8.25 up to (but not including) 0.9.0.

### Recommendations

It is strongly recommended to lock the pragma version to the specific Solidity compiler version intended for the final deployment and used during the audit and testing phases.
Replace pragmas like pragma solidity ^0.8.25; with a fixed version, for example:

```
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25; // Lock to the specific version

```
