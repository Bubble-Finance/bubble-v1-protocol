// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { MonadexV1Factory } from "@src/core/MonadexV1Factory.sol";
import { MDX } from "@src/governance/MDX.sol";
import { MonadexV1Governor } from "@src/governance/MonadexV1Governor.sol";
import { MonadexV1Timelock } from "@src/governance/MonadexV1Timelock.sol";
import { MonadexV1Types } from "@src/library/MonadexV1Types.sol";
import { MonadexV1Raffle } from "@src/raffle/MonadexV1Raffle.sol";

/// @title AttachGovernance.
/// @author Monadex Labs -- mgnfy-view.
/// @notice This contract allows you to attach the governance modules to the core protocol.
contract AttachGovernance is Script {
    address public s_protocolTeamMultisig;

    // MDX token constructor args
    uint256 public s_initialSupply;

    // Timelock constructor args
    uint256 public s_minDelay;
    address[] public s_proposers;
    address[] public s_executors;

    // Governor constructor args
    uint48 public s_initialVotingDelay;
    uint32 public s_initialVotingPeriod;
    uint256 public s_initialProposalThreshold;
    uint256 public s_quorum;

    MonadexV1Factory public s_factory;
    MonadexV1Raffle public s_raffle;
    MDX public s_mdx;
    MonadexV1Timelock public s_timelock;
    MonadexV1Governor public s_governor;

    function setUp() public {
        // placeholder values, change on each run

        s_factory = MonadexV1Factory(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        s_raffle = MonadexV1Raffle(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);

        _initializeGovernanceConstructorArgs();
    }

    function run() public returns (MDX, MonadexV1Timelock, MonadexV1Governor) {
        _initializeGovernanceConstructorArgs();

        vm.startBroadcast();

        s_mdx = new MDX(s_protocolTeamMultisig, s_initialSupply);
        s_timelock = new MonadexV1Timelock(s_minDelay, s_proposers, s_executors);
        s_governor = new MonadexV1Governor(
            s_mdx,
            s_timelock,
            s_initialVotingDelay,
            s_initialVotingPeriod,
            s_initialProposalThreshold,
            s_quorum
        );

        bytes32 proposerRole = s_timelock.PROPOSER_ROLE();
        bytes32 executorRole = s_timelock.EXECUTOR_ROLE();

        s_timelock.grantRole(proposerRole, address(s_governor));
        s_timelock.grantRole(executorRole, address(0));

        s_factory.transferOwnership(address(s_timelock));
        s_raffle.transferOwnership(address(s_timelock));

        vm.stopBroadcast();

        return (s_mdx, s_timelock, s_governor);
    }

    function _initializeGovernanceConstructorArgs() internal {
        // placeholder values, change on each run

        s_protocolTeamMultisig = 0xE5261f469bAc513C0a0575A3b686847F48Bc6687;

        s_initialSupply = 1_000_000_000e18;

        s_minDelay = 2 days; // The time after which a proposal can be executed after it has passed

        // Monad may have large number of blocks per second, unlike Ethereum which has a block per 12 sec
        // Might need to inflate these values quite a bit
        s_initialVotingDelay = uint48(7200); // The time after which voting begins, in blocks
        s_initialVotingPeriod = uint32(50400); // The time duration for which the voting lasts, in blocks
        s_initialProposalThreshold = 50e18; // The amount of MDX you must hold before creating a proposal
        s_quorum = 4; // Pretty standard, Compound uses this as well
    }
}
