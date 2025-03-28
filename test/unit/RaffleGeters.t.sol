// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Raffle
//  FUNCTIONS TESTED: 24
// ----------------------------------

// ----------------------------------
//  TEST:
//  0. getEntropy() --> @audit-note internal put as _getEntropy()
//  1. getEpochDuration()
//  2. getTiers()
//  3. getWinnersInTier1()
//  4. getWinnersInTier2()
//  5. getWinnersInTier3()
//  6. getBubbleV1Router()
//  7. getPyth()
//  8. getEntropyContract()
//  9. getEntropyProvider()
//  10. getSupportedTokens()

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

// import { ASuperTest } from "test/unit/ASuperTest.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleGetters is Test, Deployer {
    // ----------------------------------
    //    CONS
    // ----------------------------------

    // ----------------------------------
    //    getRouterAddress()
    // ----------------------------------

    function test_getEpochDuration() public view {
        uint256 epochDuration = s_raffle.getEpochDuration();
        assertEq(epochDuration, 1 weeks);
    }

    function test_getTiers() public view {
        uint256 tiers = s_raffle.getTiers();
        assertEq(tiers, 3);
    }

    function test_getWinnersInTier1() public view {
        uint256 winnersInTier1 = s_raffle.getWinnersInTier1();
        assertEq(winnersInTier1, 1);
    }

    function test_getWinnersInTier2() public view {
        uint256 winnersInTier2 = s_raffle.getWinnersInTier2();
        assertEq(winnersInTier2, 2);
    }

    function test_getWinnersInTier3() public view {
        uint256 winnersInTier3 = s_raffle.getWinnersInTier3();
        assertEq(winnersInTier3, 3);
    }

    function test_getRouterAddress() public view {
        address routerAddress = s_raffle.getBubbleV1Router();
        assertEq(routerAddress, address(s_router));
    }

    function test_getPyth() public view {
        address pythAddress = s_raffle.getPyth();
        assertEq(pythAddress, address(s_pythPriceFeedContract));
    }

    function test_getEntropyContract() public view {
        address entropyAddress = s_raffle.getEntropyContract();
        assertEq(entropyAddress, s_entropyContract);
    }

    function test_getEntropyProvider() public view {
        address providerAddress = s_raffle.getEntropyProvider();
        assertEq(providerAddress, s_entropyContract);
    }

    function test_getSupportedTokens() public view {
        address[] memory supportedTokens = s_raffle.getSupportedTokens();
        assertEq(supportedTokens[0], address(wMonad));
    }

    function test_getMinimumNftsToBeMintedEachEpoch() public view {
        uint256 nftMinimum = s_raffle.getMinimumNftsToBeMintedEachEpoch();
        assertEq(nftMinimum, 10);
    }
}
