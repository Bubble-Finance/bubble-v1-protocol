// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Bubble Contracts Imports
// --------------------------------

// 1. Libraries
import { BubbleV1Types } from "./../../src/library/BubbleV1Types.sol";

// 2. Factory
import { BubbleV1Factory } from "./../../src/core/BubbleV1Factory.sol";

// 3. Raffle
import { BubbleV1Raffle } from "./../../src/raffle/BubbleV1Raffle.sol";

// 4. Router
import { BubbleV1Router } from "./../../src/router/BubbleV1Router.sol";

// 5. Governor

import { BubbleGovernanceToken } from "./../../src/governance/BubbleGovernanceToken.sol";
import { BubbleV1Governor } from "./../../src/governance/BubbleV1Governor.sol";
import { BubbleV1Timelock } from "./../../src/governance/BubbleV1Timelock.sol";

// 6. FOT
import { FeeOnTransferToken } from "@test/utils/FeeOnTransferTokenMock.sol";

// --------------------------------
//    Helpers Contracts Imports
// --------------------------------
import { InitializeActors } from "./InitializeActors.sol";
import { InitializeConstructorArgs } from "test/baseHelpers/InitializeConstructorArgs.sol";

contract Deployer is Test, InitializeActors, InitializeConstructorArgs {
    // --------------------------------
    //    Governor: Not developed yet
    // --------------------------------
    BubbleGovernanceToken s_bubbleGovernanceToken;
    BubbleV1Timelock s_timelock;
    BubbleV1Governor s_governor;
    FeeOnTransferToken s_fotToken;

    // --------------------------------
    //    Main Contracts: Factory, Raffle, Router
    // --------------------------------
    BubbleV1Factory s_factory;

    BubbleV1Raffle s_raffle;

    BubbleV1Router s_router;

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
        s_bubbleGovernanceToken = new BubbleGovernanceToken(protocolTeamMultisig, s_initialSupply);
        s_timelock = new BubbleV1Timelock(s_minDelay, s_proposers, s_executors);
        s_governor = new BubbleV1Governor(
            s_bubbleGovernanceToken,
            s_timelock,
            s_initialVotingDelay,
            s_initialVotingPeriod,
            s_initialProposalThreshold,
            s_quorum
        );

        // --------------------------------
        //    Deploy Factory
        // --------------------------------

        s_factory = new BubbleV1Factory(protocolTeamMultisig, s_protocolFee, s_feeTiers);

        // --------------------------------
        //    Deploy Raffle
        // --------------------------------

        s_raffle = new BubbleV1Raffle(
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
        s_router = new BubbleV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeBubbleV1Router(address(s_router));
        s_raffle.supportToken(s_wNative, s_priceFeedConfigs[0]);

        vm.stopPrank();

        // -------------------------------------------
        //     Fee on transfer Initialize
        // -------------------------------------------
        vm.prank(fot);
        s_fotToken = new FeeOnTransferToken("Fee on transfer Token", "FOT", 1_000_000, 300, fot);
    }
}
