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
        // @audit-check lastTimeStamp:  1 for the first period
        uint256 lastTimeStamp = s_raffle.getLastTimestamp();
        console.log("lastTimeStamp: ", lastTimeStamp);
    }

    // ----------------------------------
    //    getSupportedTokens()
    // ----------------------------------
    function test_getSupportedTokens() public {
        address[] memory supportedTokens = s_raffle.getSupportedTokens();
        assertEq(supportedTokens[0], s_wNative);
        assertEq(supportedTokens.length, 1);

        vm.startPrank(protocolTeamMultisig);
        MonadexV1Types.PriceFeedConfig[4] memory _pythPriceFeedConfig = [
            // MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoMonadUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptowBTCUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoDAIUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoUSDTUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoSHIBUSD, noOlderThan: 60 })
        ];

        s_raffle.supportToken(address(wBTC), _pythPriceFeedConfig[0]);
        s_raffle.supportToken(address(DAI), _pythPriceFeedConfig[1]);
        s_raffle.supportToken(address(USDT), _pythPriceFeedConfig[2]);
        s_raffle.supportToken(address(SHIB), _pythPriceFeedConfig[3]);
        vm.stopPrank();

        supportedTokens = s_raffle.getSupportedTokens();
        assertEq(supportedTokens[3], address(USDT));
        assertEq(supportedTokens.length, 5);
    }

    // ----------------------------------
    //    isSupportedToken()
    // ----------------------------------

    function test_isSupportedToken() public {
        vm.startPrank(protocolTeamMultisig);
        MonadexV1Types.PriceFeedConfig[4] memory _pythPriceFeedConfig = [
            // MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoMonadUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptowBTCUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoDAIUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoUSDTUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoSHIBUSD, noOlderThan: 60 })
        ];

        s_raffle.supportToken(address(wBTC), _pythPriceFeedConfig[0]);
        s_raffle.supportToken(address(DAI), _pythPriceFeedConfig[1]);
        vm.stopPrank();

        assertEq(s_raffle.isSupportedToken(address(wBTC)), true);
        assertEq(s_raffle.isSupportedToken(address(DAI)), true);
        assertEq(s_raffle.isSupportedToken(address(USDT)), false);
        assertEq(s_raffle.isSupportedToken(address(SHIB)), false);
    }

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

    function test_isRegistrationOpen() public {
        /*
         * @audit-check registration is open after 6 days but:
         * if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION + REGISTRATION_PERIOD) return false;
         * RAFFLE_DURATION = 6 days;
         * REGISTRATION_PERIOD = 1 days;
         */
        bool isOpen = s_raffle.isRegistrationOpen();
        assertEq(isOpen, false);
        vm.warp(block.timestamp + 6 days);
        isOpen = s_raffle.isRegistrationOpen();
        assertEq(isOpen, true);
    }

    // ----------------------------------
    //    hasRegistrationPeriodEnded()
    // ----------------------------------
}
