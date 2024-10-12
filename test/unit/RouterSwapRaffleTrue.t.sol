// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
//  FUNCTIONS TESTED: 6
//  THIS TEST HAS RAFFLE TICKETS SET TO TRUE
//  THE ONLY PORPUSE OF THIS TEST THE CAPACITY OF USER TO BUY TICKETS
//  IF THE ARE MAKING SWAPS. WE ARE JUST CHECKIN `purchaseTickets: true`
//  AFTER SET `purchaseTickets: true` THE ROUTER CALLS s_raffle.purchaseTickets()
// ----------------------------------

// ----------------------------------
//  TEST:
// ** ROUTER **
//  1. swapExactTokensForTokens()
//  2. swapTokensForExactTokens()
//  3. swapExactNativeForTokens()
//  4. swapTokensForExactNative()
//  5. swapExactTokensForNative()
//  6. swapNativeForExactTokens()
// ** RAFFLE **
//  7. s_raffle.purchaseTickets()
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

contract RouterSwapRaffleTrue is Test, Deployer, RouterAddLiquidity {
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

    // --------------------------------
    //    Tests
    // --------------------------------

    // --------------------------------
    //    ADD Supported Tokens
    // --------------------------------

    function test_supportTokenGetSupported() public {
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

        address[] memory supportedTokens = s_raffle.getSupportedTokens();
        assertEq(address(wMonad), supportedTokens[0]);
        assertEq(address(wBTC), supportedTokens[1]);
        assertEq(address(DAI), supportedTokens[2]);
        assertEq(supportedTokens.length, 5);
        vm.stopPrank();
    }

    // --------------------------------
    //    swapExactTokensForTokens
    // --------------------------------

    function test_swapDAIForWBTCAndBuyTickets() public addSupportedTokens {
        // 1. Lets add some cash to the pool:
        test_secondSupplyAddDAI_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(DAI), address(wBTC));

        uint256 balance_swapper1_DAI = DAI.balanceOf(swapper1);
        uint256 balance_swapper1_wBTC = wBTC.balanceOf(swapper1);
        uint256 balance_pool_DAI = DAI.balanceOf(pool);
        uint256 balance_pool_wBTC = wBTC.balanceOf(pool);

        /**
         * SWAP START *
         */
        // 1. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(wBTC);

        // 2. Purchase tickets = true
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        // PythStructs.Price memory price = s_pythPriceFeedContract.getPrice(cryptoMonadUSD);

        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            multiplier: MonadexV1Types.Multipliers.Multiplier1,
            minimumTicketsToReceive: 0
        });

        // 3. swap
        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_10K);
        DAI.approve(address(s_raffle), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        // 4. Checks:
        assertEq(DAI.balanceOf(swapper1), balance_swapper1_DAI - ADD_10K - ADD_10K);
        console.log("tickets DAI balance: ", ERC20(s_raffle).balanceOf(swapper1) / 1e32);
    }

    function test_swapUSDTForWBTCAndBuyTickets() public addSupportedTokens {
        // 1. Lets add some cash to the pool:
        test_initialSupplyAddUSDT_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(USDT), address(wBTC));

        uint256 balance_swapper1_USDT = USDT.balanceOf(swapper1);
        uint256 balance_swapper1_wBTC = wBTC.balanceOf(swapper1);
        uint256 balance_pool_USDT = USDT.balanceOf(pool);
        uint256 balance_pool_wBTC = wBTC.balanceOf(pool);

        /**
         * SWAP START *
         */
        // 1. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(wBTC);

        // 2. Purchase tickets = true
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        // PythStructs.Price memory price = s_pythPriceFeedContract.getPrice(cryptoMonadUSD);

        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            multiplier: MonadexV1Types.Multipliers.Multiplier1,
            minimumTicketsToReceive: 0
        });

        // 3. SWAP AND PURCHASE TICKETS
        vm.startPrank(swapper2);
        USDT.approve(address(s_router), ADD_10K);
        USDT.approve(address(s_raffle), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper2, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        // 4. Checks
        /// zzz
        assertEq(USDT.balanceOf(swapper2), balance_swapper1_USDT - ADD_10K - ADD_10K);
        console.log("tickets USDT balances: ", ERC20(s_raffle).balanceOf(swapper1) / 1e32);
    }

    function test_checkDecimalsInBuyTickets() public {
        test_swapDAIForWBTCAndBuyTickets();
        test_initialSupplyAddUSDT_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(USDT), address(wBTC));

        uint256 balance_swapper1_USDT = USDT.balanceOf(swapper1);
        uint256 balance_swapper1_wBTC = wBTC.balanceOf(swapper1);
        uint256 balance_pool_USDT = USDT.balanceOf(pool);
        uint256 balance_pool_wBTC = wBTC.balanceOf(pool);

        /**
         * SWAP START *
         */
        // 1. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(wBTC);

        // 2. Purchase tickets = true
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        // PythStructs.Price memory price = s_pythPriceFeedContract.getPrice(cryptoMonadUSD);

        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            multiplier: MonadexV1Types.Multipliers.Multiplier1,
            minimumTicketsToReceive: 0
        });

        // 3. swap
        vm.startPrank(swapper2);
        USDT.approve(address(s_router), ADD_10K);
        USDT.approve(address(s_raffle), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper2, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        // 4. Checks
        /// zzz
        assertEq(USDT.balanceOf(swapper2), balance_swapper1_USDT - ADD_10K - ADD_10K);
        console.log("tickets swapper1: ", ERC20(s_raffle).balanceOf(swapper1) / 1e32);
        console.log("tickets swapper2: ", ERC20(s_raffle).balanceOf(swapper2) / 1e32);
    }
}
