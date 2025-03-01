// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

// 1. Libraries
import { MonadexV1Types } from "./../../src/library/MonadexV1Types.sol";

// 2. Factory
import { MonadexV1Factory } from "./../../src/core/MonadexV1Factory.sol";

// 3. Raffle
import { MonadexV1Raffle } from "./../../src/raffle/MonadexV1Raffle.sol";

// 4. Router
import { MonadexV1Router } from "./../../src/router/MonadexV1Router.sol";

// 5. Governor
import { MDX } from "./../../src/governance/MDX.sol";
import { MonadexV1Governor } from "./../../src/governance/MonadexV1Governor.sol";
import { MonadexV1Timelock } from "./../../src/governance/MonadexV1Timelock.sol";

// --------------------------------
//    Helpers Contracts Imports
// --------------------------------
import { InitializeActors } from "./InitializeActors.sol";
import { InitializeConstructorArgs } from "test/baseHelpers/InitializeConstructorArgs.sol";

contract Deployer is Test, InitializeActors, InitializeConstructorArgs {
    // --------------------------------
    //    Governor: Not developed yet
    // --------------------------------
    MDX s_mdx;
    MonadexV1Timelock s_timelock;
    MonadexV1Governor s_governor;

    // --------------------------------
    //    Main Contracts: Factory, Raffle, Router
    // --------------------------------
    MonadexV1Factory s_factory;

    MonadexV1Raffle s_raffle;

    MonadexV1Router s_router;

    function setUp() public {
        initializeBaseUsers();
        initializeFactoryConstructorArgs();
        initializePythMockAndPrices();
        initializeEntropy();
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
            address(s_pythPriceFeedContract),
            s_entropyContract,
            s_entropyContract,
            s_minimumNftsToBeMintedEachEpoch,
            s_winningPortions,
            s_uri
        );

        // --------------------------------
        //    Deploy Router
        // --------------------------------
        s_router = new MonadexV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeMonadexV1Router(address(s_router));
        s_raffle.supportToken(s_wNative, s_priceFeedConfigs[0]);

        vm.stopPrank();
    }
}
