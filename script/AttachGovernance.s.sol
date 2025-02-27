// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { FactoryScriptBase } from "./utils/FactoryScriptBase.sol";
import { GovernanceScriptBase } from "./utils/GovernanceScriptBase.sol";
import { MonadexV1Factory } from "@src/core/MonadexV1Factory.sol";
import { MDX } from "@src/governance/MDX.sol";
import { MonadexV1Governor } from "@src/governance/MonadexV1Governor.sol";
import { MonadexV1Timelock } from "@src/governance/MonadexV1Timelock.sol";
import { MonadexV1Raffle } from "@src/raffle/MonadexV1Raffle.sol";

/// @title AttachGovernance.
/// @author Monadex Labs -- mgnfy-view.
/// @notice This contract allows you to attach the governance modules to the core protocol.
contract AttachGovernance is FactoryScriptBase, GovernanceScriptBase, Script {
    MonadexV1Factory public s_factory;
    MonadexV1Raffle public s_raffle;
    MDX public s_mdx;
    MonadexV1Timelock public s_timelock;
    MonadexV1Governor public s_governor;

    function setUp() public {
        // placeholder values, change on each run

        s_factory = MonadexV1Factory(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        s_raffle = MonadexV1Raffle(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);

        _initializeFactoryConstructorArgs();
        _initializeGovernanceConstructorArgs();
    }

    function run() public returns (MDX, MonadexV1Timelock, MonadexV1Governor) {
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
}
