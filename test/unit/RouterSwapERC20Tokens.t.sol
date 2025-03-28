// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Router
//  FUNCTIONS TESTED: 2
//  *IMPORTANT* THIS TEST HAS RAFFLE TICKETS SET TO FALSE
//  THE PORPUSE IS TEST THE SWAPS
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. swapExactTokensForTokens()
//  2. swapTokensForExactTokens()
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

contract RouterSwapERC20Tokens is Test, Deployer, RouterAddLiquidity {
    // ----------------------------------
    //    swapExactTokensForTokens()
    // ----------------------------------
    function test_swap10K_DAIForwBTC() public {
        // 1. Lets add some cash to the pool:
        test_secondSupplyAddDAI_WBTC();

        // 2. A few checks before the start:
        s_factory.getTokenPairToPool(address(DAI), address(wBTC));

        uint256 balance_swapper1_DAI = DAI.balanceOf(swapper1);

        /**
         * SWAP START *
         */
        // 3. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(wBTC);

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
            fractionOfSwapAmount: fractionTiers[1],
            raffleNftReceiver: address(swapper1)
        });

        // 5. swap
        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 6. check the swap, not the formula yet @audit-note
        console.log("final balance user DAI: ", DAI.balanceOf(swapper1) / 1e18); // 990000e18
        console.log("final balance user wBTC: ", wBTC.balanceOf(swapper1) / 1e18); // 1001929e18
        assertEq(DAI.balanceOf(swapper1), balance_swapper1_DAI - ADD_10K);
    }

    // ----------------------------------
    //    swapTokensForExactTokens()
    // ----------------------------------
    function test_swapwBTCToObtain10K_DAI() public {
        // 1. Lets add some cash to the pool:
        test_secondSupplyAddDAI_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(DAI), address(wBTC));

        uint256 balance_swapper1_DAI = DAI.balanceOf(swapper1);

        /**
         * SWAP START *
         */
        // 3. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(wBTC);
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

        // 3. swap
        /*
         * @audit-note check this error if approve ADD_100k
         * ailing tests:
         * Encountered 1 failing test in test/unit/RouterSwapERC20Tokens.t.sol:RouterSwapERC20Tokens
         * [FAIL. Reason: BubbleV1Router__ExcessiveInputAmount(40080160320641282565131 [4.008e22], 10000000000000000000000 [1e22])] test_swapwBTCToObtain10K_DAI() (gas: 3018974)
         */
        vm.startPrank(swapper1);
        wBTC.approve(address(s_router), ADD_50K);
        s_router.swapTokensForExactTokens(
            600e18, ADD_50K, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 5. check the swap, not the formula yet @audit-note
        console.log("");
        console.log("final balance user DAI: ", DAI.balanceOf(swapper1) / 1e18); // 1000600e18
        console.log("final balance user wBTC: ", wBTC.balanceOf(swapper1) / 1e18); // 959919
        console.log("final pool user DAI: ", DAI.balanceOf(pool) / 1e18); // 299400e18
        console.log("final pool user wBTC: ", wBTC.balanceOf(pool) / 1e18); // 100080e18
        console.log("");
        console.log("");
        assertEq(DAI.balanceOf(swapper1), balance_swapper1_DAI + 600 ether);
    }
}
