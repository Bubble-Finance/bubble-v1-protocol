// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --------------------------------------------
//  CONTRACT: TEST THE INITIAL CONDITIONS
//  NUMBER OF USERS: 25
//  ERC20 FUNDS: 1e24 X ALL USERS X ALL TOKENS
//  NATIVE FUNDS: 1e24 X ALL USERS
//  TOKENS DEPLOYED: 6
//  NATIVE TOKEN: ETH. wNative: wMonad
//  ORACLE: 1 d
// --------------------------------------------

// ----------------------------------
//  TEST:
//  1. Check that the users are 25
//  2. Check that the users funds for all ERC20 are 1M
//  3. Check that the users funds for Native token are 1M
//  4. Check addresses exists for protocol contracts
//  5. Check addresses exists for ERC20 Tokens and wMonad
//  6. Check we can transfer ERC20 or native between users
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------
import { Test, console } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Pool } from "src/core/MonadexV1Pool.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// ------------------------------------------------------

contract InitialConditionsTest is Test, Deployer {
    function test_numberOfUsers() public view {
        assertEq(actors.length, 25);
    }

    function test_usersERC20Funds() public view {
        assertEq(wETH.balanceOf(LP1), TOKEN_1M);
        assertEq(wETH.balanceOf(LP5), TOKEN_1M);
        assertEq(wBTC.balanceOf(LP4), TOKEN_1M);
        assertEq(wBTC.balanceOf(swapper1), TOKEN_1M);
        assertEq(USDT.balanceOf(LP10), TOKEN_1M);
        assertEq(USDT.balanceOf(swapper2), TOKEN_1M);
        assertEq(DAI.balanceOf(LP12), TOKEN_1M);
        assertEq(USDT.balanceOf(swapper2), TOKEN_1M);
        assertEq(SHIB.balanceOf(LP9), TOKEN_1M);
        assertEq(SHIB.balanceOf(swapper8), TOKEN_1M);
    }

    function test_nativeETH() public view {
        assertEq(LP1.balance, TOKEN_1M);
        assertEq(LP7.balance, TOKEN_1M);
        assertEq(swapper1.balance, TOKEN_1M);
        assertEq(swapper10.balance, TOKEN_1M);
    }

    function test_addressOfMonadexContracts() public view {
        assert(address(s_factory) != address(0));
        assert(address(s_raffle) != address(0));
        assert(address(s_router) != address(0));
    }

    function test_addressOfERC20Tokens() public view {
        assert(address(wETH) != address(0));
        assert(address(wBTC) != address(0));
        assert(address(DAI) != address(0));
        assert(address(USDT) != address(0));
        assert(address(SHIB) != address(0));
    }

    function test_transfersERC20orNativeBetweenUsers() public {
        // @audit-note TODO
    }
}
