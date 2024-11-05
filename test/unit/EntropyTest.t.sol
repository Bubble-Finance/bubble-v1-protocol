// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract EntropyTest is Test, Deployer {
/* function test_addresses() public view {
        console.log("mock: ", address(mock));
        console.log("initializeEntropy: ", address(mockEntropy));
    }

    function test_requestNumber() public {
        uint128 requestFee = mock.getFee(address(mock));
        mockEntropy.request(userRandomNumber);
        uint256 theRaffleRandomNumber = mockEntropy.getRandomNumber();
        console.log("Enthropy Fees: ", requestFee);
        console.log("Raffle Random Number: ", theRaffleRandomNumber);
    } */
}
