// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
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
//    Monadex Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

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

        address[] memory path = new address[](2);
        path[0] = s_wNative;
        path[1] = address(DAI);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        MonadexV1Types.Raffle memory raffleParameters = MonadexV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);

        s_router.swapExactNativeForTokens{ value: ADD_10K }(
            1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();
    }
    // ----------------------------------
    //    swapTokensForExactNative()
    // ----------------------------------

    // @audit-note This path does not work:
    // path[0] = s_wNative;
    // path[1] = address(DAI);
    // @audit-note wNative withdraw is failing. Review
    // *********** in addition, review wMonad contract how they will do withdraws as eth use transfer.
    // @audit-high commented because I have to create a correct native token -- Auditor Review pending!
    /* function test_swapTokensForExactNative() public {
        test_initialSupplyAddNative_DAI();

        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = s_wNative;

        // 4. User don't want raffle tickets: This is not the objetive of this test
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        MonadexV1Types.Raffle memory raffleParameters = MonadexV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(swapper1)
        });

        vm.startPrank(swapper1);
        console.log("swapper 1: ", swapper1);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapTokensForExactNative(
            1 ether, ADD_10K, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank(); 
    }*/
    // ----------------------------------
    //    swapExactTokensForNative()
    // ----------------------------------

    // ----------------------------------
    //    swapNativeForExactTokens()
    // ----------------------------------
}
