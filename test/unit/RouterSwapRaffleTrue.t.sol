// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Router
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

import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Bubble Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { BubbleV1Library } from "src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "src/library/BubbleV1Types.sol";

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

    // --------------------------------
    //    Tests
    // --------------------------------

    // --------------------------------
    //    ADD Supported Tokens
    // --------------------------------

    function test_supportTokenGetSupported() public {
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

        // 3. swap
        vm.startPrank(swapper1);
        // Swapper1 are swapping 10K DAI for wBTC
        // In addition, is using 300 DAI to buy tickets.
        DAI.approve(address(s_router), ADD_10K + 300e18);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, raffleParameters
        );

        vm.stopPrank();

        // 4. Checks:
        assertEq(DAI.balanceOf(swapper1), (balance_swapper1_DAI - ADD_10K - 300e18));
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

        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: true,
            fractionOfSwapAmount: fractionTiers[0],
            raffleNftReceiver: address(swapper1)
        });

        // 3. SWAP AND PURCHASE TICKETS
        vm.startPrank(swapper2);
        USDT.approve(address(s_router), ADD_10K + 100e18);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper2, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 4. Checks
        assertEq(USDT.balanceOf(swapper2), balance_swapper1_USDT - ADD_10K - 100e18);
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

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: true,
            fractionOfSwapAmount: fractionTiers[4],
            raffleNftReceiver: address(swapper1)
        });

        // 3. swap
        vm.startPrank(swapper2);
        USDT.approve(address(s_router), ADD_10K + 500e18);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper2, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 4. Checks
        assertEq(USDT.balanceOf(swapper2), balance_swapper1_USDT - ADD_10K - 500e18);
    }
}
