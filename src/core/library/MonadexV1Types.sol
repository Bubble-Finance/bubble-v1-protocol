// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MonadexV1Types {
    /**
     * @notice The fee is always a percentage of the amount in consideration.
     */
    struct Fee {
        uint256 numerator;
        uint256 denominator;
    }

    /**
     * @notice Users leveraging flash swaps and flash loans can execute custom
     * logic before and after a swap by setting these values.
     */
    struct HookConfig {
        bool hookBeforeCall;
        bool hookAfterCall;
    }

    /**
     * @notice We had to pack parameters for swapping into a struct to avoid stack
     * too deep errors.
     */
    struct SwapParams {
        uint256 amountAOut;
        uint256 amountBOut;
        address receiver;
        HookConfig hookConfig;
        bytes data;
    }
}
