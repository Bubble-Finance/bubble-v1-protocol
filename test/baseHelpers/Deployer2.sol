// SPDX-License-Identifier: MIT
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

import { BubbleV1Campaigns } from "../../src/campaigns/BubbleV1Campaigns.sol";

// --------------------------------
//    Helpers Contracts Imports
// --------------------------------
import { InitializeActors } from "./InitializeActors.sol";

import { IPythMock } from "test/baseHelpers/IPythMock.sol";
import { InitializeConstructorArgs } from "test/baseHelpers/InitializeConstructorArgs.sol";
import { MockEntropy } from "test/baseHelpers/MockEntropy.sol";

contract Deployer2 is Test, InitializeActors, InitializeConstructorArgs {
    IPythMock IpythMock = new IPythMock();
    // --------------------------------
    //    Governor: Not developed yet
    // --------------------------------
    BubbleGovernanceToken s_bubbleGovernanceToken;
    BubbleV1Timelock s_timelock;
    BubbleV1Governor s_governor;

    // --------------------------------
    //    Main Contracts: Factory, Raffle, Router
    // --------------------------------
    BubbleV1Factory s_factory;

    BubbleV1Raffle s_raffle;

    BubbleV1Router s_router;

    BubbleV1Campaigns s_BubbleV1Campaigns;

    MockEntropy mock2; // provider and entropy;
    bytes32 userRandomNumber2 = 0x85f0ce7392d4ff75162f550c8a2679da7b3c39465d126ebae57b4bb126423d3a;

    function setUp() public {
        //vm.createSelectFork(vm.rpcUrl("monad"));
        console2.log("createSaelect Started...");
        //initializeBaseUsers();
        console2.log("initializeSaelect Started...");
        initializeFactoryConstructorArgs();
        initializePythMockAndPrices();
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

        mock2 = new MockEntropy(userRandomNumber2);

        s_raffle = new BubbleV1Raffle(
            address(IpythMock),
            address(mock2),
            address(mock2),
            s_fee,
            s_minimumNftsToBeMintedEachEpoch,
            s_winningPortions,
            s_uri
        );
        console2.log("s_MockPyth:", address(IpythMock));

        // --------------------------------
        //    Deploy Router
        // --------------------------------
        s_router = new BubbleV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeBubbleV1Router(address(s_router));
        //s_raffle.supportToken(s_wNative, s_priceFeedConfigs[0]);

        // -------------------------------
        //    Deploy Campaign
        // --------------------------------

        s_BubbleV1Campaigns = new BubbleV1Campaigns(
            s_minimumTokenTotalSupply,
            s_minimumVirutalNativeReserve,
            s_minimumNativeAmountToRaise,
            s_fee,
            s_tokenCreatorReward,
            s_tokenProtocolMitrationFee,
            address(s_router),
            address(s_WNative),
            address(s_TestVault)
        );
        vm.stopPrank();
    }
}
