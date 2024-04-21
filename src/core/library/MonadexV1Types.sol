// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MonadexV1Types {
    struct Fee {
        uint256 numerator;
        uint256 denominator;
    }

    struct HookConfig {
        bool hookBeforeCall;
        bool hookAfterCall;
    }
}
