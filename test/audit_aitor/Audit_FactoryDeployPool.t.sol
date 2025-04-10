// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
// AMM - POOL CREATION:
// contracts:
//  1. BubbleV1Factory
//  2. BuubleV1Pool
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. @audit-note Check if it is possible to deploy a contract but not initialize.
//  2. @audit-high The protocol need a mechanism to move the funds in case of is_locked is activate.

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

import { BubbleV1Pool } from "src/core/BubbleV1Pool.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

import { Test, console2 } from "lib/forge-std/src/Test.sol";

contract Audit_FactoryDeployPool is Test, Deployer {
    // ----------------------------------
    //    deployPool()
    // ----------------------------------

    function test_CannotFrontrunInitialize() public {
        BubbleV1Pool s_pool = BubbleV1Pool();
        vm.prank(blackHat);
        vm.expectRevert("Not factory");
        s_pool.initialize(address(wETH), address(DAI)); // Should fail
    }

    function test_deployPools() public {
        vm.startPrank(LP1);

        bytes32 salt = keccak256(abi.encodePacked(address(wETH), address(DAI)));
        bytes32 hashPreAddress = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(s_factory), salt, keccak256(type(BubbleV1Pool).creationCode)
            )
        );

        address preAddress = address(uint160(uint256(hashPreAddress)));

        address newPool = s_factory.deployPool(address(wETH), address(DAI));
        address getTokenPairPool = s_factory.getTokenPairToPool(address(wETH), address(DAI));
        assertEq(preAddress, newPool);
        assertEq(preAddress, getTokenPairPool);
    }
}
