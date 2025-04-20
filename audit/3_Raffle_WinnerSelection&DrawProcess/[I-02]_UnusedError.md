## [INFORMATIONAL-02] Unused error.

### Status

pending

### Severity: (Impact x Probability): Informatoional (16)

Impact: N/A ; probability: N/A;

### Date created 18TH OF APRIL 2025

### Summary / PoC

The error below was never used throughout the codebase.

- Found in src/raffle/BubbleV1Raffle.sol [Line: 156](src/raffle/BubbleV1Raffle.sol#L156)
  ```solidity
      error BubbleV1Raffle__RandomNumberAlreadyRequested();
  ```

### Recommendations

remove the following line from the `src/raffle/BubbleV1Raffle.sol` contract.

    ```diff
        error BubbleV1Raffle__RandomNumberAlreadyRequested();
    ```
