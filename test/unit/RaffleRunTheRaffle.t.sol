// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Raffle
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

import { Test, console } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

import { RouterAddLiquidity } from "test/unit/RouterAddLiquidity.t.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleRunTheRaffle is Test, Deployer {
// --------------------------------
//    CONS
// --------------------------------

// --------------------------------
//    initializeRouterAddress()
// --------------------------------

// --------------------------------
//    purchaseTickets()
// --------------------------------

// --------------------------------
//    register()
// --------------------------------

// --------------------------------
//    requestRandomNumber()
// --------------------------------

// --------------------------------
//    drawWinnersAndAllocateRewards()
// --------------------------------

// --------------------------------
//    claimWinnings()
// --------------------------------

// --------------------------------
//    removeToken()
// --------------------------------
}
