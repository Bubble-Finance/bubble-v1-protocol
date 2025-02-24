// SPDX-License-Identifier: MIT
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

import {MonadexV1Campaigns} from "../../src/campaigns/MonadexV1Campaigns.sol";

// --------------------------------
//    Helpers Contracts Imports
// --------------------------------
import { InitializeActors } from "./InitializeActors.sol";
import { InitializeConstructorArgs } from "test/baseHelpers/InitializeConstructorArgs.sol";
import { MockEntropy } from "test/baseHelpers/MockEntropy.sol";
import {IPythMock} from "test/baseHelpers/IPythMock.sol";

contract Deployer2 is Test, InitializeActors, InitializeConstructorArgs {
    IPythMock IpythMock = new IPythMock();
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

    MonadexV1Campaigns  s_MonadexV1Campaigns;

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

        mock2 = new MockEntropy(userRandomNumber2);


        s_raffle = new MonadexV1Raffle(
            address(IpythMock),
            address(mock2),
            address(mock2),
            s_minimumNftsToBeMintedEachEpoch,
            s_winningPortions
        );
        console2.log("s_MockPyth:", address(IpythMock));

        // --------------------------------
        //    Deploy Router
        // --------------------------------
        s_router = new MonadexV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeMonadexV1Router(address(s_router));
        //s_raffle.supportToken(s_wNative, s_priceFeedConfigs[0]);

        // -------------------------------
        //    Deploy Campaign
        // --------------------------------

        s_MonadexV1Campaigns = new MonadexV1Campaigns(
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



