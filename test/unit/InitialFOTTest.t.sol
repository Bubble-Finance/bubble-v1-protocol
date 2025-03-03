// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Deployer } from "@test/baseHelpers/Deployer.sol";
import { Test, console2 } from "forge-std/Test.sol";

contract InitialFOTTest is Test, Deployer {
    function testContractAddressIsNotZero() public view {
        console2.log("Fot address: ", address(s_fotToken));
        assertTrue(address(s_fotToken) != address(0), "Contract address should not be zero");
    }
}
