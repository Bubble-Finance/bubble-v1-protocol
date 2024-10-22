// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test, console } from "lib/forge-std/src/Test.sol";

import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

import { InitializeEntropy } from "test/baseHelpers/InitializeEntropy.sol";
import { MockEntropy } from "test/baseHelpers/MockEntropy.sol";

contract EntropyTest is Test {
    MockEntropy mock; // provider;
    bytes32 userRandomNumber = 0x85f0ce7392d4ff75162f550c8a2679da7b3c39465d126ebae57b4bb126423d3a;

    InitializeEntropy initializeEntropy;

    function setUp() public {
        mock = new MockEntropy(userRandomNumber);
        initializeEntropy = new InitializeEntropy(address(mock), address(mock));
    }

    function test_addresses() public view {
        console.log("mock: ", address(mock));
        console.log("initializeEntropy: ", address(initializeEntropy));
    }

    function test_requestNumber() public {
        uint128 requestFee = mock.getFee(address(mock));
        initializeEntropy.request(userRandomNumber);
        uint256 theRaffleRandomNumber = initializeEntropy.getRandomNumber();
        console.log("Enthropy Fees: ", requestFee);
        console.log("Raffle Random Number: ", theRaffleRandomNumber);
    }
}
