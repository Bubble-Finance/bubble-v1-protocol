// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Raffle
//  FUNCTIONS TESTED: 18
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. getRouterAddress()
//  2. getLastTimestamp()
//  3. getSupportedTokens()
//  4. isSupportedToken()
//  5. getUserAtRangeStart()
//  6. getCurrentRangeEnd()
//  7. getMultiplierToPercentage()
//  8. getWinningPortions()
//  9. getWinnings()
//  10. getRaffleDuration()
//  11. getRegistrationPeriod()
//  12. getMaxWinners()
//  13. getMaxTiers()
//  14. getMaxMultipliers()
//  15. getMinimumParticipantsForRaffle()
//  16. previewPurchase()
//  17. isRegistrationOpen()
//  18. hasRegistrationPeriodEnded()
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

import { RouterAddLiquidity } from "test/unit/RouterAddLiquidity.t.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { RouterSwapRaffleTrue } from "test/unit/RouterSwapRaffleTrue.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleGetters is Test, Deployer, RouterSwapRaffleTrue {
    // ----------------------------------
    //    CONS
    // ----------------------------------

    // ----------------------------------
    //    getRouterAddress()
    // ----------------------------------

    function test_getRouterAddress() public view {
        address routerAddress = s_raffle.getRouterAddress();
        assertEq(routerAddress, address(s_router));
    }

    // ----------------------------------
    //    getLastTimestamp()
    // ----------------------------------

    function test_getLastTimestamp() public view {
        uint256 lastTimeStamp = s_raffle.getLastTimestamp();
        console.log("sss: ", lastTimeStamp);
    }

    // ----------------------------------
    //    getSupportedTokens()
    // ----------------------------------

    // ----------------------------------
    //    isSupportedToken()
    // ----------------------------------

    // ----------------------------------
    //    getUserAtRangeStart()
    // ----------------------------------

    // ----------------------------------
    //    getCurrentRangeEnd()
    // ----------------------------------

    // ----------------------------------
    //    getMultiplierToPercentage()
    // ----------------------------------

    // ----------------------------------
    //    getWinningPortions()
    // ----------------------------------

    // ----------------------------------
    //    getWinnings()
    // ----------------------------------

    // ----------------------------------
    //    getRaffleDuration()
    // ----------------------------------

    // ----------------------------------
    //    getRegistrationPeriod()
    // ----------------------------------

    // ----------------------------------
    //    getMaxWinners()
    // ----------------------------------

    // ----------------------------------
    //    getMinimumParticipantsForRaffle()
    // ----------------------------------

    // ----------------------------------
    //    previewPurchase()
    // ----------------------------------

    // ----------------------------------
    //    isRegistrationOpen()
    // ----------------------------------

    // ----------------------------------
    //    hasRegistrationPeriodEnded()
    // ----------------------------------
}
