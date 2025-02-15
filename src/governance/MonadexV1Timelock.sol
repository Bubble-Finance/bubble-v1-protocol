// Layout:
//     - pragma
//     - imports
//     - interfaces, libraries, contracts
//     - type declarations
//     - state variables
//     - events
//     - errors
//     - modifiers
//     - functions
//         - constructor
//         - receive function (if exists)
//         - fallback function (if exists)
//         - external
//         - public
//         - internal
//         - private
//         - view and pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimelockController } from
    "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

/// @title MonadexV1Timelock.
/// @author Monadex Labs -- Ola hamid.
/// @notice MonadexV1Timelock manages delayed execution of transactions.
contract MonadexV1Timelock is TimelockController {
    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Initializes the timelock.
    /// @param minDelay The waiting time before you can execute a transaction.
    /// @param proposers The list of addresses that can propose.
    /// @param executors The list of addresses that can execute.
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    )
        TimelockController(minDelay, proposers, executors, msg.sender)
    { }
}
