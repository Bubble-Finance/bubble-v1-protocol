// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title BubbleV1Timelock.
/// @author Bubble Finance -- Ola hamid.
/// @notice BubbleV1Timelock manages delayed execution of transactions.
contract BubbleV1Timelock is TimelockController {
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
