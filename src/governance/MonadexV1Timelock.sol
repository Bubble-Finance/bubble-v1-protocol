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
pragma solidity 0.8.20;
/// @title MDX(Monadex) Token  
/// @author Ola hamid
/// @notice MonadexV1Timelock manages delayed execution of transactions.

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MonadexV1Timelock is TimelockController { 

    // minDelay is how long you have to wait before executing
    // proposers is the list of addresses that can propose
    // executors is the list of addresses that can execute
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
