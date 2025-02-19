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
import { MockEntropyContract } from "test/baseHelpers/MockEntropyContract.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract PythEntropyTest is Test, Deployer {
    function test_addresses() public view {
        console.log("mock: ", address(mock));
        console.log("initializeEntropy: ", address(mockEntropy));
    }

    function test_requestNumber() public {
        mockEntropy.request(userRandomNumber);
        uint256 theRaffleRandomNumber = mockEntropy.getRandomNumber();
        console.log("Raffle Random Number: ", theRaffleRandomNumber);

        mockEntropy.request(userRandomNumber);
        uint256 theRaffleRandomNumber2 = mockEntropy.getRandomNumber();
        console.log("Raffle Random Number: ", theRaffleRandomNumber2);

        mockEntropy.request(userRandomNumber);
        uint256 theRaffleRandomNumber3 = mockEntropy.getRandomNumber();
        console.log("Raffle Random Number: ", theRaffleRandomNumber3);
    }
}
