// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Router
//  FUNCTIONS TESTED: 5
//  This test execute several operations in a single function, like
//  create pool, add liquidity, swaps, remove liquidity, swap again,...
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. s_factory.deployPool()
//  2. s_router.addLiquidity() x 2
//  3. s_router.swapExactTokensForTokens()
//  4. s_router.addLiquidity() - again
//  5. s_router.swapTokensForExactTokens()
//  6. s_router.removeLiquidity()
//  7. s_router.swapExactTokensForTokens() - again
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

contract RouterSeveralOperations is Test, Deployer {
    // ** For tokens with 18 decimals **
    uint256 constant ADD_10K = 10000e18;
    uint256 constant ADD_50K = 50000e18;
    uint256 constant ADD_100K = 10000e18;
    uint256 constant ADD_500K = 500000e18;

    // ** For tokens with 6 decimals **
    uint256 constant USDT_10K = 10000e6;
    uint256 constant USDT_50K = 50000e6;
    uint256 constant USDT_100K = 100000e6;
    uint256 constant USDT_500K = 500000e6;

    function test_executeSeveralRouterFunctions() public {
        /**
         * 1. CREATE POOL
         *  Create pool: The first thing is to have pools to add liquidity so we use the factory contract.
         *  If a user wants to add liquidity to a non-existing pool, the pool will be created automatically first.
         */
        vm.prank(LP1);
        address pool = s_factory.deployPool(address(wBTC), address(DAI));

        /*
         * 2. ADD LIQUIDITY
         * To start operating the pool, liquidity needs to be added.
         * Having created the pool does not grant any privileges.
         * You need 2 tokens, although one can be 1Me18 and the other 1 wei.
         */
        vm.startPrank(LP1);
        wBTC.approve(address(s_router), ADD_10K);
        DAI.approve(address(s_router), ADD_50K);

        // Note: deadline = max deadLine possible => 1921000304
        BubbleV1Types.AddLiquidity memory liquidityLP1 = BubbleV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(DAI),
            amountADesired: ADD_10K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });
        (,, uint256 lpTokensMintedLP1) = s_router.addLiquidity(liquidityLP1);
        vm.stopPrank();

        /*
         * 3. ADD A SECOND LIQUIDITY
         * Any user can add liquidity from now on.
         */
        vm.startPrank(LP2);
        wBTC.approve(address(s_router), ADD_50K);
        DAI.approve(address(s_router), ADD_500K);

        // Note: deadline = max deadLine possible => 1921000304
        BubbleV1Types.AddLiquidity memory liquidityLP2 = BubbleV1Types.AddLiquidity({
            tokenA: address(DAI),
            tokenB: address(wBTC),
            amountADesired: ADD_500K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP2,
            deadline: block.timestamp
        });
        s_router.addLiquidity(liquidityLP2);
        vm.stopPrank();

        /*
         * 4. START SWAPPING
         * Once liquidity is available, we can start swapping.
         * Any user can make swaps.
         * Swapping gives you the ability to buy lottery tickets,
         * so you have to specify whether you want them or not, as they have a cost.
         * In this example, it is set to NO, lottery tests will be added during the week.
         */
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(wBTC);

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

        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        /*
         * 5. ADDING MORE LIQUIDITY
         * It is always possible to add more liquidity, any user can do so.
         */
        vm.startPrank(LP3);
        wBTC.approve(address(s_router), ADD_10K);
        DAI.approve(address(s_router), ADD_100K);

        // Note: deadline = max deadLine possible => 1921000304
        BubbleV1Types.AddLiquidity memory liquidityLP3 = BubbleV1Types.AddLiquidity({
            tokenA: address(DAI),
            tokenB: address(wBTC),
            amountADesired: ADD_10K,
            amountBDesired: ADD_100K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP3,
            deadline: block.timestamp
        });
        s_router.addLiquidity(liquidityLP3);
        vm.stopPrank();

        /*
         * 5. MORE SWAPS
         * Any user can swap as long as there is liquidity.
         * IN this case, we are re-using path and purchaseTickets
         */
        vm.startPrank(swapper3);
        DAI.approve(address(s_router), 9000 ether);
        s_router.swapTokensForExactTokens(
            5 ether, 9000 ether, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        /*
         * 6. REMOVE LIQUIDITY
         * Users can remove their liquidity at any moment
         */
        vm.startPrank(LP1);
        ERC20(pool).approve(address(s_router), lpTokensMintedLP1);
        s_router.removeLiquidity(
            address(wBTC),
            address(DAI),
            lpTokensMintedLP1,
            ADD_10K / 2,
            ADD_50K / 2,
            LP1,
            block.timestamp
        );
        vm.stopPrank();

        /*
         * 7. MOVE ON: MORE SWAPS, MORE ADD, MORE REMOVE...
         */
        vm.startPrank(swapper10);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();
    }
}
