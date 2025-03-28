// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACTS: BubbleV1Factory, BubbleV1Router, BubbleV1Raffle
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

import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Bubble Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { BubbleV1Library } from "src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "src/library/BubbleV1Types.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { RouterSwapRaffleTrue } from "test/unit/RouterSwapRaffleTrue.t.sol";

// ------------------------------------------------------
//    Import Previous Tests
// -----------------------------------------------------
import { FactoryDeployPool } from "test/unit/FactoryDeployPool.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleSetInitialSwaps is Test, FactoryDeployPool {
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
        BubbleV1Types.PriceFeedConfig[4] memory _pythPriceFeedConfig = [
            // BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoMonadUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptowBTCUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoDAIUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoUSDTUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoSHIBUSD, noOlderThan: 60 })
        ];

        s_raffle.supportToken(address(wBTC), _pythPriceFeedConfig[0]);
        s_raffle.supportToken(address(DAI), _pythPriceFeedConfig[1]);
        s_raffle.supportToken(address(USDT), _pythPriceFeedConfig[2]);
        s_raffle.supportToken(address(SHIB), _pythPriceFeedConfig[3]);
        vm.stopPrank();
        _;
    }

    // -----------------------------------
    //    Step 1: Deploy Multiple Pools
    // -----------------------------------
    function test_deployAllThePools() public {
        test_deployPools();
        test_deployMultiplePools();
    }

    // --------------------------------------------------
    //    Step 2: Add Liquidity to all the pools deployed
    // --------------------------------------------------

    function test_addLiquidityToPoolsDeployedPreviously() public {
        test_deployAllThePools();

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

        // 2. Configure the BubbleV1Types.AddLiquidity for all the pools:
        BubbleV1Types.AddLiquidity memory liquiditypoolwETHDAI = BubbleV1Types.AddLiquidity({
            tokenA: address(wETH),
            tokenB: address(DAI),
            amountADesired: ADD_10K,
            amountBDesired: ADD_20K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        BubbleV1Types.AddLiquidity memory liquiditypoolwBTCUSDT = BubbleV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(USDT),
            amountADesired: ADD_10K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP2,
            deadline: block.timestamp
        });

        BubbleV1Types.AddLiquidity memory liquiditypoolwETHSHIB = BubbleV1Types.AddLiquidity({
            tokenA: address(wETH),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP3,
            deadline: block.timestamp
        });

        BubbleV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_100K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP4,
            deadline: block.timestamp
        });

        BubbleV1Types.AddLiquidity({
            tokenA: address(USDT),
            tokenB: address(SHIB),
            amountADesired: ADD_10K,
            amountBDesired: ADD_20K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP5,
            deadline: block.timestamp
        });

        BubbleV1Types.AddLiquidity({
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
        s_router.addLiquidity(liquiditypoolwETHDAI);

        vm.prank(LP2);
        s_router.addLiquidity(liquiditypoolwBTCUSDT);

        vm.prank(LP3);
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
    function test_startSwappinfUsingExistingPools() public addSupportedTokens {
        test_addLiquidityToPoolsDeployedPreviously();

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

        // 3. Set swap conditions
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: true,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        console2.log("******* START HERE ********");
        console2.log("** Initial Conditions **");
        console2.log("swappers 1 to 5 swap DAIs x wETH");

        // 4. SWAPS IN POOL DAI / WETH
        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_10K + 300e18);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path1, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper2);
        DAI.approve(address(s_router), ADD_2K + 60e18);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path1, swapper2, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper3);
        DAI.approve(address(s_router), ADD_3K * 2);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path1, swapper3, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper4);
        DAI.approve(address(s_router), ADD_5K * 2);
        s_router.swapExactTokensForTokens(
            ADD_5K, 1, path1, swapper4, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper5);
        DAI.approve(address(s_router), ADD_10K * 2);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path1, swapper5, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 5. SWAPS IN POOL USDT / WBTC
        vm.startPrank(swapper6);
        USDT.approve(address(s_router), ADD_1K * 2);
        s_router.swapExactTokensForTokens(
            ADD_1K, 1, path2, swapper6, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper7);
        USDT.approve(address(s_router), ADD_2K * 2);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path2, swapper7, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper8);
        USDT.approve(address(s_router), ADD_3K * 2);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path2, swapper8, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper9);
        USDT.approve(address(s_router), ADD_5K * 2);
        s_router.swapExactTokensForTokens(
            ADD_5K, 1, path2, swapper9, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        vm.startPrank(swapper10);
        USDT.approve(address(s_router), ADD_10K * 2);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path2, swapper10, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 6. SWAPS IN POOL WETH / SHIB
        // @audit-note I fail to register swap in path3 >>> REVIEW!!!!
        vm.startPrank(swapper11);
        USDT.approve(address(s_router), ADD_3K * 2);
        s_router.swapExactTokensForTokens(
            ADD_3K, 1, path2, swapper11, block.timestamp, raffleParameters
        );

        USDT.approve(address(s_router), ADD_2K * 2);
        s_router.swapExactTokensForTokens(
            ADD_2K, 1, path2, swapper12, block.timestamp, raffleParameters
        );
        vm.stopPrank();
    }
}
