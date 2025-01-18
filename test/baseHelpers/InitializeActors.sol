// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: InitializeActors
//  1. Deploy users to be used on TESTS.
//  2. protocolTeamMultisig: Admin user.
//  3. LP: Liquidity Pool users.
//  4. Swappers: Swap and Raffle users.
//  5. Stockers: Governor users
//  ** Every user has 1M of every token included native Monad. **
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console2 } from "./../../lib/forge-std/src/Test.sol";

import { InitializeTokens } from "./InitializeTokens.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// ------------------------------------------------------

contract InitializeActors is Test, InitializeTokens {
    // ------------
    //    Actors
    // ------------

    // ** ADMIN ACTORS: PROPOSED BY THE PROTOCOL **
    address protocolTeamMultisig = makeAddr("mulprotocolTeamMultisigtiSig"); // Multi-sign wallet and deployer
    address protocolTeamMultisig2 = makeAddr("mulprotocolTeamMultisigtiSig2"); // Alternate Multi-sign wallet and deployer

    // liquidity Providers:
    address LP1 = makeAddr("LP1");
    address LP2 = makeAddr("LP2");
    address LP3 = makeAddr("LP3");
    address LP4 = makeAddr("lp4");
    address LP5 = makeAddr("LP5");
    address LP6 = makeAddr("LP6");
    address LP7 = makeAddr("LP7");
    address LP8 = makeAddr("LP8");
    address LP9 = makeAddr("LP9");
    address LP10 = makeAddr("LP10");
    address LP11 = makeAddr("LP11");
    address LP12 = makeAddr("LP12");

    // swappers: Swap tokens and participate in the raffle
    address swapper1 = makeAddr("swapper1");
    address swapper2 = makeAddr("swapper2");
    address swapper3 = makeAddr("swapper3");
    address swapper4 = makeAddr("swapper4");
    address swapper5 = makeAddr("swapper5");
    address swapper6 = makeAddr("swapper6");
    address swapper7 = makeAddr("swapper7");
    address swapper8 = makeAddr("swapper8");
    address swapper9 = makeAddr("swapper9");
    address swapper10 = makeAddr("swapper10");
    address swapper11 = makeAddr("swapper11");
    address swapper12 = makeAddr("swapper12");

    // Staker: Potential staker of Monadex Token (jic)
    address stacker1 = makeAddr("stacker1");
    address stacker2 = makeAddr("stacker2");
    address stacker3 = makeAddr("stacker3");
    address stacker4 = makeAddr("stacker4");

    // BlackHats: Malicious Actor
    address blackHat = makeAddr("blackHat");

    address[] public actors;

    function addActorsTotheArray() public {
        actors.push(LP1);
        actors.push(LP2);
        actors.push(LP3);
        actors.push(LP4);
        actors.push(LP5);
        actors.push(LP6);
        actors.push(LP7);
        actors.push(LP8);
        actors.push(LP9);
        actors.push(LP10);
        actors.push(LP11);
        actors.push(LP12);
        actors.push(swapper1);
        actors.push(swapper2);
        actors.push(swapper3);
        actors.push(swapper4);
        actors.push(swapper5);
        actors.push(swapper6);
        actors.push(swapper7);
        actors.push(swapper8);
        actors.push(swapper9);
        actors.push(swapper10);
        actors.push(swapper11);
        actors.push(swapper12);
        actors.push(blackHat);
    }

    function initializeBaseUsers() public {
        addActorsTotheArray();

        // 1. Add ERC20 funds
        for (uint256 i = 0; i < actors.length; ++i) {
            wETH.mint(actors[i], TOKEN_1M);
            wBTC.mint(actors[i], TOKEN_1M);
            USDT.mint(actors[i], TOKEN_1M);
            DAI.mint(actors[i], TOKEN_1M);
            SHIB.mint(actors[i], TOKEN_1M);
        }

        // 2. Add Native funds
        for (uint256 i = 0; i < actors.length; ++i) {
            vm.deal(actors[i], TOKEN_1M);
        }
    }
}
