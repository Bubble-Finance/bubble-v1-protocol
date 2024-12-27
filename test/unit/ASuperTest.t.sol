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

contract ASuperTest is Test, FactoryDeployPool {
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
    modifier addSupportedTokens() {
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
        _;
    }

    // -----------------------------------
    //    Step 1: Deploy MUltiple Pools
    // -----------------------------------

    function test_deployPoolsInSuperTest() public {
        test_deployPools();
        test_deployMultiplePools();
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
         * poolwETHDAI:  0x4Cae1e9f8a967B0B725112F839C0C6F3aC9b51A8
         * poolwBTCUSDT:  0x4Ee331311d26ac4b06492a17445964D322df21C4
         * poolwETHSHIB:  0xBf43986169D31b187DFDEB4F5721AA5Fb9070c02
         * poolwBTCSHIB:  0x200245Ca3745c6Ba51541534D996959DB4F2E7E6
         * poolUSDTSHIB:  0x2837fE249aF1768B96C1105727cf787F7CC3fCC8
         * poolDAISHIB:  0x9c49cff1D3272a4266D8bf2943D1c8D3109d1C59
         */
    }

    // --------------------------------------------------
    //    Step 2: Add Liquidity to all the pools deployed
    // --------------------------------------------------

    function test_addLiquidityToPoolsDeployedInSuperTest() public {
        test_deployPoolsInSuperTest();

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
        vm.startPrank(LP4);
        wBTC.approve(address(s_router), ADD_10K);
        SHIB.approve(address(s_router), ADD_100K);
        vm.stopPrank();
        vm.startPrank(LP5);
        USDT.approve(address(s_router), ADD_10K);
        SHIB.approve(address(s_router), ADD_20K);
        vm.stopPrank();
        vm.startPrank(LP6);
        DAI.approve(address(s_router), ADD_10K);
        SHIB.approve(address(s_router), ADD_20K);
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

        MonadexV1Types.AddLiquidity memory liquiditypoolwBTCSHIB = MonadexV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_100K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP4,
            deadline: block.timestamp
        });

        MonadexV1Types.AddLiquidity memory liquiditypoolUSDTSHIB = MonadexV1Types.AddLiquidity({
            tokenA: address(USDT),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_20K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP5,
            deadline: block.timestamp
        });

        MonadexV1Types.AddLiquidity memory liquiditypoolDAISHIB = MonadexV1Types.AddLiquidity({
            tokenA: address(DAI),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_20K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP6,
            deadline: block.timestamp
        });

        // 3. Add Liquidity to the pools:
        vm.prank(LP1);
        (uint256 aLP1, uint256 bLP1, uint256 lpTokensLP1) =
            s_router.addLiquidity(liquiditypoolwETHDAI);

        vm.prank(LP2);
        (uint256 aLP2, uint256 bLP2, uint256 lpTokensLP2) =
            s_router.addLiquidity(liquiditypoolwBTCUSDT);

        vm.prank(LP3);
        (uint256 aLP3, uint256 bLP3, uint256 lpTokensLP3) =
            s_router.addLiquidity(liquiditypoolwETHSHIB);

        // NOTE: STACK TOO DEEP
        /*        vm.prank(LP4);
        (uint256 aLP4, uint256 bLP4, uint256 lpTokensLP4) =
            s_router.addLiquidity(liquiditypoolwBTCSHIB);

        vm.prank(LP5);
        (uint256 aLP5, uint256 bLP5, uint256 lpTokensLP5) =
            s_router.addLiquidity(liquiditypoolUSDTSHIB);

        vm.prank(LP6);
        (uint256 aLP6, uint256 bLP6, uint256 lpTokensLP6) =
            s_router.addLiquidity(liquiditypoolDAISHIB); */
    }

    // ----------------------------------------------------------
    //    Step 3: Start swaping and buiyng tickets
    //            using all the pools deployed
    // ---------------------------------------------------------
    function test_swapUsingExistingPoolsFromTheSuperTest() public addSupportedTokens {
        test_addLiquidityToPoolsDeployedInSuperTest();

        // 1. Feed ERC20/wNative Token Exchange
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        // 2. Calculate paths:
        address[] memory path1 = new address[](2);
        path1[0] = address(DAI);
        path1[1] = address(wETH);

        address[] memory path2 = new address[](2);
        path2[0] = address(USDT);
        path2[1] = address(wBTC);

        address[] memory path3 = new address[](2);
        path3[0] = address(wETH);
        path3[1] = address(SHIB);

        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_1000 }), // 0.1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_1000 }), // 0.2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_1000 }), // 0.3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_1000 }), // 0.4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_1000 }) // 0.4%
        ];

        // 2. User don't want raffle tickets: This is not the objetive of this test
        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[1],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper1)
        });

        // 4. SWAPS IN POOL DAI / WETH
        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_1K * 2);
        s_router.swapExactTokensForTokens(
            ADD_1K, 1, path1, swapper1, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper2);
        DAI.approve(address(s_router), ADD_2K * 2);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path1, swapper2, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper3);
        DAI.approve(address(s_router), ADD_3K * 2);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path1, swapper3, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper4);
        DAI.approve(address(s_router), ADD_5K * 2);
        s_router.swapExactTokensForTokens(
            ADD_5K, 1, path1, swapper4, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper5);
        DAI.approve(address(s_router), ADD_10K * 2);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path1, swapper5, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        console.log("TICKETS OWNED BY USERS: ");
        console.log("tickets swapper1: ", ERC20(s_raffle).balanceOf(swapper1));
        console.log("tickets swapper2: ", ERC20(s_raffle).balanceOf(swapper2));
        console.log("tickets swapper3: ", ERC20(s_raffle).balanceOf(swapper3));
        console.log("tickets swapper4: ", ERC20(s_raffle).balanceOf(swapper4));
        console.log("tickets swapper5: ", ERC20(s_raffle).balanceOf(swapper5));

        // 5. SWAPS IN POOL USDT / WBTC
        vm.startPrank(swapper6);
        USDT.approve(address(s_router), ADD_1K * 2);
        s_router.swapExactTokensForTokens(
            ADD_1K, 1, path2, swapper6, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper7);
        USDT.approve(address(s_router), ADD_2K * 2);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path2, swapper7, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper8);
        USDT.approve(address(s_router), ADD_3K * 2);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path2, swapper8, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper9);
        USDT.approve(address(s_router), ADD_5K * 2);
        s_router.swapExactTokensForTokens(
            ADD_5K, 1, path2, swapper9, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        vm.startPrank(swapper10);
        USDT.approve(address(s_router), ADD_10K * 2);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path2, swapper10, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        console.log("tickets swapper6: ", ERC20(s_raffle).balanceOf(swapper6));
        console.log("tickets swapper7: ", ERC20(s_raffle).balanceOf(swapper7));
        console.log("tickets swapper8: ", ERC20(s_raffle).balanceOf(swapper8));
        console.log("tickets swapper9: ", ERC20(s_raffle).balanceOf(swapper9));
        console.log("tickets swapper10: ", ERC20(s_raffle).balanceOf(swapper10));

        // 6. SWAPS IN POOL WETH / SHIB
        // @audit-note I fail to register swap in path3 >>> REVIEW!!!!
        vm.startPrank(swapper11);
        USDT.approve(address(s_router), ADD_3K * 2);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path2, swapper11, block.timestamp, purchaseTickets
        );

        USDT.approve(address(s_router), ADD_2K * 2);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path2, swapper12, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        console.log("tickets swapper11: ", ERC20(s_raffle).balanceOf(swapper11));
        console.log("tickets swapper12: ", ERC20(s_raffle).balanceOf(swapper12));
        console.log("");
        console.log("");
    }

    function test_allSuperTestSwappersRegisterTickets() public {
        test_swapUsingExistingPoolsFromTheSuperTest();

        vm.warp(block.timestamp + 6 days);

        console.log("USERS REGISTER 1000E18 TICKETS EACH");
        console.log("");
        console.log("");
        vm.prank(swapper1);
        s_raffle.register(swapper1, 1000e18);
        vm.prank(swapper2);
        s_raffle.register(swapper2, 1000e18);
        vm.prank(swapper3);
        s_raffle.register(swapper3, 1000e18);
        vm.prank(swapper4);
        s_raffle.register(swapper4, 1000e18);
        vm.prank(swapper5);
        s_raffle.register(swapper5, 1000e18);
        vm.prank(swapper6);
        s_raffle.register(swapper6, 1000e18);
        vm.prank(swapper7);
        s_raffle.register(swapper7, 1000e18);
        vm.prank(swapper8);
        s_raffle.register(swapper8, 1000e18);
        vm.prank(swapper9);
        s_raffle.register(swapper9, 1000e18);
        vm.prank(swapper10);
        s_raffle.register(swapper10, 1000e18);
        vm.prank(swapper11);
        s_raffle.register(swapper11, 1000e18);
        vm.prank(swapper12);
        s_raffle.register(swapper12, 1000e18);
    }
}
