// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACTS: MonadexV1Factory, MonadexV1Router, MonadexV1Raffle
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

import { RouterSwapRaffleTrue } from "test/unit/RouterSwapRaffleTrue.t.sol";

// ------------------------------------------------------
//    Import Previous Tests
// -----------------------------------------------------
import { FactoryDeployPool } from "test/unit/FactoryDeployPool.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------
contract AAFrontendTest is Test, FactoryDeployPool {
    uint256 constant ADD_1K = 1_000e18;
    uint256 constant ADD_2K = 2_000e18;
    uint256 constant ADD_3K = 3_000e18;
    uint256 constant ADD_5K = 5_000e18;
    uint256 constant ADD_10K = 10_000e18;
    uint256 constant ADD_20K = 20_000e18;
    uint256 constant ADD_50K = 50_000e18;
    uint256 constant ADD_100K = 100_000e18;
    uint256 constant ADD_200K = 200_000e18;
    uint256 constant ADD_500K = 500_000e18;

    // --------------------------------
    //    Modifiers
    // --------------------------------
    modifier addSupportedTokensAndDEployPools() {
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

        test_deployPools();
        test_deployMultiplePools();

        vm.stopPrank();
        _;
    }

    // ---------------------------------------------------
    //    Check if the modifier works
    // ---------------------------------------------------

    function test_FrontEndTestDeployPools() public addSupportedTokensAndDEployPools {
        address poolwETHDAI = s_factory.getTokenPairToPool(address(wETH), address(DAI));
        address poolwBTCUSDT = s_factory.getTokenPairToPool(address(wBTC), address(USDT));
        address poolwETHSHIB = s_factory.getTokenPairToPool(address(wETH), address(SHIB));
        address poolwBTCSHIB = s_factory.getTokenPairToPool(address(wBTC), address(SHIB));
        address poolUSDTSHIB = s_factory.getTokenPairToPool(address(USDT), address(SHIB));
        address poolDAISHIB = s_factory.getTokenPairToPool(address(DAI), address(SHIB));

        console.log("POOLS DEPLOYED: ");
        console.log("poolwETHDAI: ", poolwETHDAI);
        console.log("poolwBTCUSDT: ", poolwBTCUSDT);
        console.log("poolwETHSHIB: ", poolwETHSHIB);
        console.log("poolwBTCSHIB: ", poolwBTCSHIB);
        console.log("poolUSDTSHIB: ", poolUSDTSHIB);
        console.log("poolDAISHIB: ", poolDAISHIB);
        console.log("");
        console.log("");

        /*
         * POOLS DEPLOYED:
         * poolwETHDAI:  0xA980B44dCbe146A84881D9eBDc7A76Bc81a841c9
         * poolwBTCUSDT:  0xe8311a9abdf67cec4222C8840fF8b3F4B27Be92D
         * poolwETHSHIB:  0xBd2F76a65cb8BD73FE8cD5408DCcCb4f7bF34DA4
         * poolwBTCSHIB:  0xb806168784827906f8462D03a388B31D0BcB0770
         * poolUSDTSHIB:  0x75d81Ef87CD22b641A54C9C4fd359d2b839fdC1D
         * poolDAISHIB:  0x33D3b35dB6Ac59d3542b1d9788b129d3B36254
         */
    }

    // ---------------------------------------------------
    //    Initial conditions:
    //      1. wBTC, DAI, USDT, SHIB withelisted for raffles
    //      2. 6 pools created
    // ---------------------------------------------------

    // --------------------------------------------------
    //    Step 1: Add Liquidity to all the pools:
    //            poolwETHDAI,poolwBTCUSDT, poolwETHSHIB
    // --------------------------------------------------
    function test_FrontEndTestAddLiqToPools() public addSupportedTokensAndDEployPools {
        // 1. Approve for router to spend a lot of  $$
        vm.startPrank(LP1);
        wETH.approve(address(s_router), ADD_10K);
        DAI.approve(address(s_router), ADD_20K);
        vm.stopPrank();
        vm.startPrank(LP2);
        wBTC.approve(address(s_router), ADD_10K);
        USDT.approve(address(s_router), ADD_50K);
        vm.stopPrank();
        vm.startPrank(LP3);
        wETH.approve(address(s_router), ADD_10K);
        SHIB.approve(address(s_router), ADD_50K);
        vm.stopPrank();

        // 2. Configure the MonadexV1Types.AddLiquidity for all the pools:
        MonadexV1Types.AddLiquidity memory liquiditypoolwETHDAI = MonadexV1Types.AddLiquidity({
            tokenA: address(wETH),
            tokenB: address(DAI),
            amountADesired: ADD_10K,
            amountBDesired: ADD_20K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        MonadexV1Types.AddLiquidity memory liquiditypoolwBTCUSDT = MonadexV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(USDT),
            amountADesired: ADD_10K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP2,
            deadline: block.timestamp
        });

        MonadexV1Types.AddLiquidity memory liquiditypoolwETHSHIB = MonadexV1Types.AddLiquidity({
            tokenA: address(wETH),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP3,
            deadline: block.timestamp
        });

        /* @audit-note: just for me >>>
        vm.prank(LP1);
        (uint256 aLP1, uint256 bLP1, uint256 lpTokensLP1) =
            s_router.addLiquidity(liquiditypoolwETHDAI);

        vm.prank(LP2);
        (uint256 aLP2, uint256 bLP2, uint256 lpTokensLP2) =
            s_router.addLiquidity(liquiditypoolwBTCUSDT);

        vm.prank(LP3);
        (uint256 aLP3, uint256 bLP3, uint256 lpTokensLP3) =
            s_router.addLiquidity(liquiditypoolwETHSHIB); */

        // 3. Add Liquidity to the pools:
        vm.prank(LP1);
        s_router.addLiquidity(liquiditypoolwETHDAI);

        vm.prank(LP2);
        s_router.addLiquidity(liquiditypoolwBTCUSDT);

        vm.prank(LP3);
        s_router.addLiquidity(liquiditypoolwETHSHIB);

        // 3. Check Liquidity in Pools:
        console.log(
            "poolwETHDAI -> wETH liquidity: ",
            wETH.balanceOf(s_factory.getTokenPairToPool(address(wETH), address(DAI)))
        );
        console.log(
            "poolwETHDAI -> DAI liquidity: ",
            DAI.balanceOf(s_factory.getTokenPairToPool(address(wETH), address(DAI)))
        );

        console.log(
            "poolwBTCUSDT -> wBTC liquidity:  ",
            wBTC.balanceOf(s_factory.getTokenPairToPool(address(wBTC), address(USDT)))
        );
        console.log(
            "poolwBTCUSDT -> USDT liquidity: ",
            USDT.balanceOf(s_factory.getTokenPairToPool(address(wBTC), address(USDT)))
        );

        console.log(
            "poolwETHSHIB -> wETH liquidity:  ",
            wETH.balanceOf(s_factory.getTokenPairToPool(address(wETH), address(SHIB)))
        );
        console.log(
            "poolwETHSHIB -> SHIB liquidity: ",
            SHIB.balanceOf(s_factory.getTokenPairToPool(address(wETH), address(SHIB)))
        );
    }

    // --------------------------------------------------
    //    Step 2:  Start swaping and buiyng tickets
    //            using all the pools deployed
    // --------------------------------------------------
    function test_FrontEndSwapAndBuyTickets() public {
        // 1. Deploy Pools, add Liquidity and whiteList tokens for raffles
        test_FrontEndTestAddLiqToPools();

        // 2. Use the Oracle PYTH (mock prices) to feed the protocol
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        // 2. Calculate paths for the swap function.
        // ** We will use s_router.swapExactTokensForTokens()
        address[] memory path1 = new address[](2);
        path1[0] = address(DAI);
        path1[1] = address(wETH);

        address[] memory path2 = new address[](2);
        path2[0] = address(USDT);
        path2[1] = address(wBTC);

        address[] memory path3 = new address[](2);
        path3[0] = address(SHIB);
        path3[1] = address(wETH);

        // 3. Add the fraction tiers
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: 1, denominator: 100 }), // 1%
            MonadexV1Types.Fraction({ numerator: 2, denominator: 100 }), // 2%
            MonadexV1Types.Fraction({ numerator: 3, denominator: 100 }), // 3%
            MonadexV1Types.Fraction({ numerator: 4, denominator: 100 }), // 4%
            MonadexV1Types.Fraction({ numerator: 5, denominator: 100 }) // 5%
        ];

        // --------------------------------------
        //    ***** SWAPS & TICKETS!!!!! *********
        // ---------------------------------------

        // 4. User swapper1 swaps 1000 DAI for wETH
        // ** Set the fraction to 1% => It will invest 10 DAIs in tickets
        // ** Need to approve 1000 + 10 DAIs to the router.
        // ** It will receive 10e18 tickets.
        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[0],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_1K + 10e18);
        s_router.swapExactTokensForTokens(
            ADD_1K, 1, path1, swapper1, block.timestamp, purchaseTickets
        );
        vm.stopPrank();
        console.log("tickets swapper1: ", ERC20(s_raffle).balanceOf(swapper1));

        // 5. User swapper2 swaps 2000 DAI for wETH
        // ** Set the fraction to 2% => It will invest 40 DAIs in tickets
        // ** Need to approve 1000 + 40 DAIs to the router.
        // ** It will receive 40e18 tickets.
        MonadexV1Types.PurchaseTickets memory purchaseTickets2 = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[1],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper2)
        });

        vm.startPrank(swapper2);
        DAI.approve(address(s_router), ADD_2K + 40e18);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path1, swapper2, block.timestamp, purchaseTickets2
        );
        vm.stopPrank();
        console.log("tickets swapper2: ", ERC20(s_raffle).balanceOf(swapper2));

        // 6. User swapper3 swaps 3000 DAI for wETH
        // ** Set the fraction to 4% => It will invest 120 DAIs in tickets
        // ** Need to approve 1000 + 1200 DAIs to the router.
        // ** It will receive 120e18 tickets.
        MonadexV1Types.PurchaseTickets memory purchaseTickets3 = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[3],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper3)
        });

        vm.startPrank(swapper3);
        DAI.approve(address(s_router), ADD_3K + 120e18);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path1, swapper3, block.timestamp, purchaseTickets3
        );
        vm.stopPrank();
        console.log("tickets swapper3: ", ERC20(s_raffle).balanceOf(swapper3));

        // 7. WE JUST CONTINUE ADDING USERS
        // *** WE NEED 10 FOR THE RAFFLES
        // *** WE USE THE OTHER POOLES
        MonadexV1Types.PurchaseTickets memory purchaseTickets4 = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[4],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper4)
        });

        vm.startPrank(swapper4);
        USDT.approve(address(s_router), ADD_1K + 50e18);
        s_router.swapExactTokensForTokens(
            ADD_1K, 1, path2, swapper4, block.timestamp, purchaseTickets4
        );
        vm.stopPrank();
        console.log("tickets swapper4: ", ERC20(s_raffle).balanceOf(swapper4));

        MonadexV1Types.PurchaseTickets memory purchaseTickets5 = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[0],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper5)
        });

        vm.startPrank(swapper5);
        USDT.approve(address(s_router), ADD_5K + 50e18);
        s_router.swapExactTokensForTokens(
            ADD_5K, 1, path2, swapper5, block.timestamp, purchaseTickets5
        );
        vm.stopPrank();
        console.log("tickets swapper5: ", ERC20(s_raffle).balanceOf(swapper5));

        MonadexV1Types.PurchaseTickets memory purchaseTickets6 = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[2],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper6)
        });

        vm.startPrank(swapper6);
        USDT.approve(address(s_router), ADD_2K + 60e18);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path2, swapper6, block.timestamp, purchaseTickets6
        );
        vm.stopPrank();
        console.log("tickets swapper6: ", ERC20(s_raffle).balanceOf(swapper6));

        MonadexV1Types.PurchaseTickets memory purchaseTickets7 = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[4],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper7)
        });

        vm.startPrank(swapper7);
        SHIB.approve(address(s_router), ADD_5K + 250e18);
        s_router.swapExactTokensForTokens(
            ADD_5K, 1, path3, swapper3, block.timestamp, purchaseTickets7
        );
        vm.stopPrank();
        console.log("tickets swapper7: ", ERC20(s_raffle).balanceOf(swapper7));
    }
}
