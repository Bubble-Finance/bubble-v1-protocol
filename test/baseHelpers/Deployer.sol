// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: Deployer
//  1. Deploy Governor.
//     @audit-note Governor is currently under development and has no effect on the protocol.
//  2. Deploy Factory.
//  3. Deploy Raffle.
//     @audit-note Raffle should be deployed before Router.
//  4. Deploy Router.
//  5. Roles and Owners after Deploy.
//     @audit-note For future use, when Governor is deployed.
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console } from "./../../lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

// 1. Libraries
import { MonadexV1Types } from "./../../src/library/MonadexV1Types.sol";

// 2. Governor
import { MDX } from "./../../src/governance/MDX.sol";
import { MonadexV1Governor } from "./../../src/governance/MonadexV1Governor.sol";
import { MonadexV1Timelock } from "./../../src/governance/MonadexV1Timelock.sol";

// 3. Factory
import { MonadexV1Factory } from "./../../src/core/MonadexV1Factory.sol";

// 4. Raffle
import { MonadexV1Raffle } from "./../../src/raffle/MonadexV1Raffle.sol";

// 5. Router
import { MonadexV1Router } from "./../../src/router/MonadexV1Router.sol";

// --------------------------------
//    Helpers Contracts Imports
// --------------------------------
import { InitializeActors } from "./InitializeActors.sol";
import { InitializeConstructorsArgs } from "./InitializeConstructorsArgs.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// ------------------------------------------------------

contract Deployer is Test, InitializeActors, InitializeConstructorsArgs {
    MDX s_mdx;
    MonadexV1Timelock s_timelock;
    MonadexV1Governor s_governor;

    MonadexV1Factory s_factory;

    MonadexV1Raffle s_raffle;

    MonadexV1Router s_router;

    function setUp() external {
        InitializeBaseUsers();
        initializeFactoryConstructorArgs();
        initializePythMockAndPrices();
        initializeRaffleConstructorArgs();

        vm.startPrank(protocolTeamMultisig);

        // --------------------------------
        //    Deploy Governor
        // --------------------------------
        s_mdx = new MDX(protocolTeamMultisig, s_initialSupply);
        s_timelock = new MonadexV1Timelock(s_minDelay, s_proposers, s_executors);
        s_governor = new MonadexV1Governor(
            s_mdx,
            s_timelock,
            s_initialVotingDelay,
            s_initialVotingPeriod,
            s_initialProposalThreshold,
            s_quorum
        );

        // --------------------------------
        //    Deploy Factory
        // --------------------------------

        s_factory = new MonadexV1Factory(protocolTeamMultisig, s_protocolFee, s_feeTiers);

        // --------------------------------
        //    Deploy Raffle
        // --------------------------------

        s_raffle = new MonadexV1Raffle(
            s_supportedTokens,
            address(s_pythPriceFeedContract),
            s_priceFeedConfigs,
            s_entropyContract,
            s_entropyProvider,
            s_multipliersToPercentages,
            s_winningPortions,
            s_minimumParticipants
        );

        // --------------------------------
        //    Deploy Router
        // --------------------------------
        s_router = new MonadexV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeRouterAddress(address(s_router));

        // --------------------------------
        //    Roles and Owners after Deploy
        // --------------------------------
        bytes32 proposerRole = s_timelock.PROPOSER_ROLE();
        bytes32 executorRole = s_timelock.EXECUTOR_ROLE();

        s_timelock.grantRole(proposerRole, address(s_governor));
        s_timelock.grantRole(executorRole, address(0));

        /**
         * PENDING *******
         *     s_factory.transferOwnership(address(s_timelock));
         *     s_raffle.transferOwnership(address(s_timelock));
         */
        vm.stopPrank();
    }
}
