// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
//  FUNCTIONS TESTED: 8
//  This test check all the get functions of the Router contract.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. getFactory()
//  2. getRaffle()
//  3. getWNative()
//  @audit-note All the below functions are pure.
//  *********** They give info to users. Need to match the values of swap functions.
//  *********** Doesn't have in count if the token has 18 or 6 decimals.
//  *********** Check if have the influence in the formulas.
//  4. quote()
//  5. getAmountOut()
//  6. getAmountIn()
//  7. getAmountsOut()
//  8. getAmountsIn()
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

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RouterGeters is Test, Deployer {
    // ----------------------------------
    //    CONS
    // ----------------------------------
    uint256 _amountA = 10_000e18;
    uint256 _reserveA = 325_000e18;
    uint256 _reserveB = 1_115_000e18;

    // ----------------------------------
    //    getFactory()
    // ----------------------------------

    function test_everyUserCanGetTheFactoryAddress() public {
        vm.prank(LP1);
        address factoryAddress = s_router.getFactory();
        assertEq(address(s_factory), factoryAddress);
    }

    // ----------------------------------
    //    getRaffle()
    // ----------------------------------

    function test_everyUserCanGetTheRaffleAddress() public {
        vm.prank(LP1);
        address raffleAddress = s_router.getRaffle();
        assertEq(address(s_raffle), raffleAddress);
    }

    // ----------------------------------
    //    getWNative()
    // ----------------------------------

    function test_everyUserCanGetTheNativeTokenAddress() public {
        vm.prank(LP1);
        address nativeAddress = s_router.getWNative();
        assertEq(address(s_wNative), nativeAddress);
    }

    // ----------------------------------
    //    quote()
    // ----------------------------------

    function test_calculatePotentialAmountB() public {
        vm.prank(LP1);
        uint256 quoteFunction = s_router.quote(_amountA, _reserveA, _reserveB);
        uint256 qouteFormula = (_amountA * _reserveB) / _reserveA;
        assertEq(quoteFunction, qouteFormula);
    }

    // ----------------------------------
    //    getAmountOut()
    // ----------------------------------

    function test_calculatePotentialAmountOut() public {
        MonadexV1Types.Fee memory _poolFee = MonadexV1Types.Fee({ numerator: 3, denominator: 1000 });

        vm.prank(LP1);
        uint256 amountOutFunction = s_router.getAmountOut(_amountA, _reserveA, _reserveB, _poolFee);

        uint256 amountInAfterFee = _amountA * (_poolFee.denominator - _poolFee.numerator);
        uint256 numerator = amountInAfterFee * _reserveB;
        uint256 denominator = (_reserveA * _poolFee.denominator) + amountInAfterFee;

        uint256 amountOutFormula = numerator / denominator;
        assertEq(amountOutFunction, amountOutFormula);
    }

    // ----------------------------------
    //    getAmountIn()
    // ----------------------------------

    // ----------------------------------
    //    getAmountsOut()
    // ----------------------------------

    // ----------------------------------
    //    getAmountsIn()
    // ----------------------------------
}
