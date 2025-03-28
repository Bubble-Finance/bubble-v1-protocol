// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Pool
//  FUNCTIONS TESTED: 8
//  This test check all the get functions of the Pool contract.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. isPoolToken()
//  2. getFactory()
//  3. getTWAPData()
//  4. getProtocolTeamMultisig()
//  5. getProtocolFee().
//  6. getPoolFee()
//  7. getPoolTokens()
//  8. getReserves()
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

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract FactoryGeters is Test, Deployer {
    function test_isPoolToken() public { }

    function test_getFactory() public { }

    function test_getTWAPData() public { }

    function test_getProtocolTeamMultisig() public { }

    function test_getProtocolFee() public { }

    function test_getPoolTokens() public { }

    function test_getReserves() public { }

    function test_getPoolFee() public { }
}
