// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Router
//  FUNCTIONS TESTED: 8
//  THIS TEST HAS RAFFLE TICKETS SET TO FALSE
//  THE PORPUSE IS TEST THE SWAPS
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. swapExactNativeForTokens()
//  2. swapTokensForExactNative()
//  3. swapExactTokensForNative()
//  4. swapNativeForExactTokens()
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Bubble Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { BubbleV1Library } from "src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "src/library/BubbleV1Types.sol";

import { RouterAddLiquidity } from "test/unit/RouterAddLiquidity.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RouterSwapNative is Test, Deployer, RouterAddLiquidity {
    // ----------------------------------
    //    swapExactNativeForTokens()
    // ----------------------------------
    function test_swapExactNativeForTokens() public {
        test_initialSupplyAddNative_DAI();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));

        console.log("***** ADDRESSESS ******");
        console.log("DAI address: ", address(DAI));
        console.log("wMonad: ", s_wNative);
        console.log("pool DAI/wMonad: ", poolAddress);
        console.log("");

        console.log("***** POOL BALANCES BEFORE *****");
        console.log("DAI balance at pool: ", DAI.balanceOf(poolAddress));
        console.log("wMonad balance at pool: ", wMonad.balanceOf(poolAddress));
        console.log("");

        console.log("***** USER BALANCES BEFORE *****");
        console.log("***** USER has 0 wMonad, he use Native *****");
        console.log("wMonad balance: ", wMonad.balanceOf(swapper1));
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");

        address[] memory path = new address[](2);
        path[0] = s_wNative;
        path[1] = address(DAI);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);

        console.log("***** User send 10K native swapping for DAIs *****");
        console.log("");

        s_router.swapExactNativeForTokens{ value: ADD_10K }(
            1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        console.log("***** POOL BALANCES AFTER *****");
        console.log("DAI balance at pool: ", DAI.balanceOf(poolAddress));
        console.log("wMonad balance at pool: ", wMonad.balanceOf(poolAddress));
        console.log("");

        console.log("***** USER BALANCES AFTER *****");
        console.log("wMonad balance is still 0: ", wMonad.balanceOf(swapper1));
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");
    }

    function test_swap100_exactNativeForTokens() public {
        test_initialSupplyAddNative_DAI();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));

        console.log("***** ADDRESSESS ******");
        console.log("DAI address: ", address(DAI));
        console.log("wMonad: ", s_wNative);
        console.log("pool DAI/wMonad: ", poolAddress);
        console.log("");

        console.log("***** POOL BALANCES BEFORE *****");
        console.log("DAI balance at pool: ", DAI.balanceOf(poolAddress));
        console.log("wMonad balance at pool: ", wMonad.balanceOf(poolAddress));
        console.log("");

        console.log("***** USER BALANCES BEFORE *****");
        console.log("***** USER has 0 wMonad, he use Native *****");
        console.log("wMonad balance: ", wMonad.balanceOf(swapper1));
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");

        address[] memory path = new address[](2);
        path[0] = s_wNative;
        path[1] = address(DAI);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);

        console.log("***** User send 100 native swapping for DAIs *****");
        console.log("");

        s_router.swapExactNativeForTokens{ value: 100 }(
            1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        console.log("***** POOL BALANCES AFTER *****");
        console.log("DAI balance at pool: ", DAI.balanceOf(poolAddress));
        console.log("wMonad balance at pool: ", wMonad.balanceOf(poolAddress));
        console.log("");

        console.log("***** USER BALANCES AFTER *****");
        console.log("wMonad balance is still 0: ", wMonad.balanceOf(swapper1));
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");
    }

    function test_swap50K_exactNativeForTokens() public {
        test_initialSupplyAddNative_DAI();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));

        console.log("***** ADDRESSESS ******");
        console.log("DAI address: ", address(DAI));
        console.log("wMonad: ", s_wNative);
        console.log("pool DAI/wMonad: ", poolAddress);
        console.log("");

        console.log("***** POOL BALANCES BEFORE *****");
        console.log("DAI balance at pool: ", DAI.balanceOf(poolAddress));
        console.log("wMonad balance at pool: ", wMonad.balanceOf(poolAddress));
        console.log("");

        console.log("***** USER BALANCES BEFORE *****");
        console.log("***** USER has 0 wMonad, he use Native *****");
        console.log("wMonad balance: ", wMonad.balanceOf(swapper1));
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");

        address[] memory path = new address[](2);
        path[0] = s_wNative;
        path[1] = address(DAI);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);

        console.log("***** User send 50K native swapping for DAIs *****");
        console.log("");

        s_router.swapExactNativeForTokens{ value: ADD_50K }(
            1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        console.log("***** POOL BALANCES AFTER *****");
        console.log("DAI balance at pool: ", DAI.balanceOf(poolAddress));
        console.log("wMonad balance at pool: ", wMonad.balanceOf(poolAddress));
        console.log("");

        console.log("***** USER BALANCES AFTER *****");
        console.log("wMonad balance is still 0: ", wMonad.balanceOf(swapper1));
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");
    }
    // ----------------------------------
    //    swapTokensForExactNative()
    // ----------------------------------

    function test_swapTokensForExactNative() public {
        test_initialSupplyAddNative_DAI();

        console.log("***** USER BALANCES BEFORE *****");
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));

        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));
        vm.deal(poolAddress, TOKEN_1M);

        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = s_wNative;

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_50K);
        s_router.swapTokensForExactNative(
            1 ether, ADD_50K, path, swapper1, block.timestamp, raffleParameters
        );

        console.log("***** USER BALANCES AFTER *****");
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");
        vm.stopPrank();
    }
    // ----------------------------------
    //    swapExactTokensForNative()
    // ----------------------------------

    function test_swapExactTokensForNative() public {
        test_initialSupplyAddNative_DAI();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));

        console.log("***** USER BALANCES BEFORE *****");
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));

        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = s_wNative;

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);

        DAI.approve(address(s_router), ADD_50K);
        s_router.swapExactTokensForNative(
            ADD_50K, 1, path, swapper1, block.timestamp, raffleParameters
        );

        console.log("***** USER BALANCES AFTER *****");
        console.log("Native balance: ", swapper1.balance);
        console.log("DAI balance: ", DAI.balanceOf(swapper1));
        console.log("");
        vm.stopPrank();
    }

    // ----------------------------------
    //    swapNativeForExactTokens()
    // ----------------------------------

    function test_swapNativeForExactTokens() public { }
}
