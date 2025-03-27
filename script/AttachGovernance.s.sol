// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { FactoryScriptBase } from "@script/utils/FactoryScriptBase.sol";
import { GovernanceScriptBase } from "@script/utils/GovernanceScriptBase.sol";
import { BubbleV1Factory } from "@src/core/BubbleV1Factory.sol";
import { BubbleGovernanceToken } from "@src/governance/BubbleGovernanceToken.sol";
import { BubbleV1Governor } from "@src/governance/BubbleV1Governor.sol";
import { BubbleV1Timelock } from "@src/governance/BubbleV1Timelock.sol";
import { BubbleV1Raffle } from "@src/raffle/BubbleV1Raffle.sol";

/// @title AttachGovernance.
/// @author Bubble Finance -- mgnfy-view.
/// @notice This contract allows you to attach the governance modules to the core protocol.
contract AttachGovernance is FactoryScriptBase, GovernanceScriptBase, Script {
    BubbleV1Factory public s_factory;
    BubbleV1Raffle public s_raffle;
    BubbleGovernanceToken public s_bubbleGovernanceToken;
    BubbleV1Timelock public s_timelock;
    BubbleV1Governor public s_governor;

    function setUp() public {
        // placeholder values, change on each run

        s_factory = BubbleV1Factory(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        s_raffle = BubbleV1Raffle(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);

        _initializeFactoryConstructorArgs();
        _initializeGovernanceConstructorArgs();
    }

    function run() public returns (BubbleGovernanceToken, BubbleV1Timelock, BubbleV1Governor) {
        vm.startBroadcast();

        s_bubbleGovernanceToken = new BubbleGovernanceToken(s_protocolTeamMultisig, s_initialSupply);
        s_timelock = new BubbleV1Timelock(s_minDelay, s_proposers, s_executors);
        s_governor = new BubbleV1Governor(
            s_bubbleGovernanceToken,
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

        return (s_bubbleGovernanceToken, s_timelock, s_governor);
    }
}
