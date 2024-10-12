// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Raffle
//  FUNCTIONS TESTED: 7
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. initializeRouterAddress()
//  2. purchaseTickets()
//  3. register()
//  4. requestRandomNumber()
//  5. drawWinnersAndAllocateRewards()
//  6. claimWinnings()
//  7. removeToken()
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

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleRunTheRaffle is Test, Deployer {
    // --------------------------------
    //    CONS
    // --------------------------------
    // NOTE: Multipliers are: 0.5%, 1%, 2%
    MonadexV1Types.Multipliers public multiplier1 = MonadexV1Types.Multipliers.Multiplier1;
    MonadexV1Types.Multipliers public multiplier2 = MonadexV1Types.Multipliers.Multiplier2;
    MonadexV1Types.Multipliers public multiplier3 = MonadexV1Types.Multipliers.Multiplier2;

    // --------------------------------
    //    initializeRouterAddress()
    // --------------------------------
    function testFail_changingTheRouterAddress() public {
        // Router address is set during the deploy:
        address routerAddress = s_raffle.getRouterAddress();
        assertEq(routerAddress, address(s_router));

        // We can not change it after the deploy!
        vm.prank(protocolTeamMultisig);
        s_raffle.initializeRouterAddress(address(s_factory));
    }

    // --------------------------------
    //    purchaseTickets()
    // --------------------------------
    // purchaseTickets() is test when the user set, in the swap, purchaseTickets: true
    // Only router can call purchaseTickets()
    function testFail_purchaseTicketsNotBeingRouter() public {
        vm.startPrank(protocolTeamMultisig);
        MonadexV1Types.PriceFeedConfig[2] memory _pythPriceFeedConfig = [
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptowBTCUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoDAIUSD, noOlderThan: 60 })
        ];

        s_raffle.supportToken(address(wBTC), _pythPriceFeedConfig[0]);
        s_raffle.supportToken(address(DAI), _pythPriceFeedConfig[1]);

        s_raffle.purchaseTickets(swapper1, address(DAI), 10000, multiplier1, swapper1);

        vm.stopPrank();
    }

    // --------------------------------
    //    register()
    // --------------------------------

    // --------------------------------
    //    requestRandomNumber()
    // --------------------------------

    // --------------------------------
    //    drawWinnersAndAllocateRewards()
    // --------------------------------

    // --------------------------------
    //    claimWinnings()
    // --------------------------------

    // --------------------------------
    //    removeToken()
    // --------------------------------
}
