// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title GovernanceScriptBase.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Provides config for governance contracts deployment.
abstract contract GovernanceScriptBase {
    uint256 public s_initialSupply;

    uint256 public s_minDelay;
    address[] public s_proposers;
    address[] public s_executors;

    uint48 public s_initialVotingDelay;
    uint32 public s_initialVotingPeriod;
    uint256 public s_initialProposalThreshold;
    uint256 public s_quorum;

    function _initializeGovernanceConstructorArgs() internal {
        // placeholder values, change on each run

        s_initialSupply = 1_000_000_000e18;

        s_minDelay = 2 days; // The time after which a proposal can be executed after it has passed

        // Monad may have large number of blocks per second, unlike Ethereum which has a block per 12 sec
        // Might need to inflate these values quite a bit
        s_initialVotingDelay = uint48(7200); // The time after which voting begins, in blocks
        s_initialVotingPeriod = uint32(50400); // The time duration for which the voting lasts, in blocks
        s_initialProposalThreshold = 50e18; // The amount of Bubble tokens you must hold before creating a proposal
        s_quorum = 4; // Pretty standard, Compound uses this as well
    }
}
