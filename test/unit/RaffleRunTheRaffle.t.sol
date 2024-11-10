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

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { ASuperTest } from "test/unit/ASuperTest.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleRunTheRaffle is Test, Deployer, ASuperTest {
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
    function testFail_userWithNoTicketsWillRevert() public {
        vm.warp(block.timestamp + 6 days);
        vm.prank(swapper1);
        s_raffle.register(100);
    }

    function test_userRegister1000Tickets() public {
        test_swapUsingExistingPoolsFromTheSuperTest();
        vm.warp(block.timestamp + 6 days);
        vm.prank(swapper1);
        uint256 ticketsToBurn = s_raffle.register(1000e18);
        assertEq(ticketsToBurn, 1000e18);
    }

    /* //@audit-note:commented bc take too long
    function test_userRegisterLimit() public {
        test_swapDAIForWBTCAndBuyTickets();

        vm.warp(block.timestamp + 6 days);

        vm.prank(swapper1);
        uint256 ticketsToBurn = s_raffle.register(1e25);
        assertEq(ticketsToBurn, 1e25);
    }
    */
    // @audit-high - Not finishing, Potential DoS attack.
    /* function test_userRegister100x100OfThetickets() public {
        test_swapDAIForWBTCAndBuyTickets(); //User swap DAI = 10K for wBTC

        uint256 swapper1TicketsBalance = ERC20(s_raffle).balanceOf(swapper1);
        assertEq(ERC20(s_raffle).balanceOf(swapper1), 1e39);

        vm.warp(block.timestamp + 6 days);
        vm.prank(swapper1);
        uint256 ticketsToBurn = s_raffle.register(swapper1TicketsBalance);
        assertEq(ticketsToBurn, swapper1TicketsBalance);
    }  */

    // --------------------------------
    //    requestRandomNumber()
    // --------------------------------
    /* function test_requestRandomNUmberUsingMockEntropyContract() public {
        vm.startPrank(LP1);
        uint128 requestFee = mock.getFee(address(mock));
        mockEntropy.request(userRandomNumber);
        uint256 theRaffleRandomNumber = mockEntropy.getRandomNumber();
        console.log("Enthropy Fees: ", requestFee);
        console.log("Raffle Random Number: ", theRaffleRandomNumber);

        vm.stopPrank();
    } */

    function test_easyRequestRandomNumber() public {
        test_allSuperTestSwappersRegisterTickets();
        console.log("AS WE ARE IN LOCAL, WE HAVE A MOCK ENTROPY CONTRACT:");
        console.log("mock contract: ", address(mock));
        console.log("MonadexV1Raffle: ", address(s_raffle));
        console.log("");

        vm.warp(block.timestamp + 6 days);

        uint128 requestFee = mock.getFee(address(mock));
        s_raffle.requestRandomNumber(userRandomNumber);
        uint256 theRaffleRandomNumber = uint256(s_raffle.getCurrentRandomNumber());
        console.log("WE SET THE FEES TO ZERO. WE HAVE A RANDOM NUMBER!:");
        console.log("Enthropy Fees: ", requestFee);
        console.log("Raffle Random Number: ", theRaffleRandomNumber);
    }

    function test_lookingFor_sequenceNumber() public {
        test_allSuperTestSwappersRegisterTickets();
        vm.warp(block.timestamp + 6 days);
        s_raffle.requestRandomNumber(userRandomNumber);
        uint256 theRaffleRandomNumber = uint256(s_raffle.getCurrentRandomNumber());
        console.log("Raffle Random Number: ", theRaffleRandomNumber);
        s_raffle.requestRandomNumber(userRandomNumber);
        theRaffleRandomNumber = uint256(s_raffle.getCurrentRandomNumber());
        console.log("Raffle Random Number: ", theRaffleRandomNumber);
    }

    // --------------------------------
    //    drawWinnersAndAllocateRewards()
    // --------------------------------
    function test_drawWinnersAndAllocateRewards() public {
        test_easyRequestRandomNumber();
        bool isEnded = s_raffle.hasRegistrationPeriodEnded();
        console.log("isEnded: ", isEnded);
        s_raffle.drawWinnersAndAllocateRewards();
    }

    // --------------------------------
    //    claimWinnings()
    // --------------------------------
    function test_claimWinning() public {
        test_drawWinnersAndAllocateRewards();
        console.log("wBTC: ", wBTC.balanceOf(address(s_raffle)));
        console.log("wETH: ", wETH.balanceOf(address(s_raffle)));
        console.log("DAI: ", DAI.balanceOf(address(s_raffle)));
        console.log("USDT: ", USDT.balanceOf(address(s_raffle)));
        console.log("SHIB: ", SHIB.balanceOf(address(s_raffle)));
        console.log("monad: ", wMonad.balanceOf(address(s_raffle)));

        vm.prank(swapper5);
        s_raffle.claimWinnings(address(DAI), address(swapper5));
        vm.prank(swapper2);
        s_raffle.claimWinnings(address(DAI), address(swapper2));
        vm.prank(swapper7);
        s_raffle.claimWinnings(address(DAI), address(swapper7));
        vm.prank(swapper10);
        s_raffle.claimWinnings(address(DAI), address(swapper10));
        vm.prank(swapper4);
        s_raffle.claimWinnings(address(DAI), address(swapper4));

        vm.prank(swapper5);
        s_raffle.claimWinnings(address(USDT), address(swapper5));
        vm.prank(swapper2);
        s_raffle.claimWinnings(address(USDT), address(swapper2));
        vm.prank(swapper7);
        s_raffle.claimWinnings(address(USDT), address(swapper7));
        vm.prank(swapper10);
        s_raffle.claimWinnings(address(USDT), address(swapper10));
        vm.prank(swapper4);
        s_raffle.claimWinnings(address(USDT), address(swapper4));

        console.log("after ****************");
        console.log("wETH: ", wETH.balanceOf(address(s_raffle)));
        console.log("DAI: ", DAI.balanceOf(address(s_raffle)));
        console.log("USDT: ", USDT.balanceOf(address(s_raffle)));
        console.log("SHIB: ", SHIB.balanceOf(address(s_raffle)));
        console.log("monad: ", wMonad.balanceOf(address(s_raffle)));
    }

    // --------------------------------
    //    removeToken()
    // --------------------------------
    function test_removeToken() public addSupportedTokens {
        assertEq(s_raffle.isSupportedToken(address(DAI)), true);
        vm.prank(protocolTeamMultisig);
        s_raffle.removeToken(address(DAI));
        assertEq(s_raffle.isSupportedToken(address(DAI)), false);
    }

    function testFail_onlyOwnerCanRemoveToken() public addSupportedTokens {
        assertEq(s_raffle.isSupportedToken(address(DAI)), true);
        vm.prank(LP1);
        s_raffle.removeToken(address(DAI));
    }
}
