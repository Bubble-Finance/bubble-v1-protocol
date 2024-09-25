// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Factory
//  GET FUNCTIONS: 3
//  This test check the deploy Pool feature.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. deployPool()
//  2. lockPool()
//  @audit-high The protocol need a mechanism to move the funds in case of is_locked is activate.
//  *********** Because the token is malicioius.
//  *********** Because the pool/pools is/are under attack.
//  3. unlockPool()

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

import { MonadexV1Pool } from "src/core/MonadexV1Pool.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

import { Test, console } from "lib/forge-std/src/Test.sol";

contract FactoryDeployPool is Test, Deployer {
    // ----------------------------------
    //   Modifiers()
    // ----------------------------------

    modifier deployNewPool() {
        vm.startPrank(LP1);
        address poolWETHDAI = s_factory.deployPool(address(wETH), address(DAI));
        vm.stopPrank();
        _;
    }

    // ----------------------------------
    //    deployPool()
    // ----------------------------------
    function test_deployPools() public {
        vm.startPrank(LP1);
        // 1. Deploy pool wETH & DAI:
        bytes32 salt = keccak256(abi.encodePacked(address(wETH), address(DAI)));
        bytes32 hashPreAddress = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(s_factory), salt, keccak256(type(MonadexV1Pool).creationCode)
            )
        );

        bytes32 initCodeHash = keccak256(abi.encodePacked(type(MonadexV1Pool).creationCode));

        address preAddress = address(uint160(uint256(hashPreAddress)));

        address newPool = s_factory.deployPool(address(wETH), address(DAI));
        address getTokenPairPool = s_factory.getTokenPairToPool(address(wETH), address(DAI));
        assertEq(preAddress, newPool);
        assertEq(preAddress, getTokenPairPool);

        // 2. Deploy pool wBTC & USDT:
        bytes32 salt2 = keccak256(abi.encodePacked(address(wBTC), address(USDT)));
        bytes32 hashPreAddress2 = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(s_factory), salt2, keccak256(type(MonadexV1Pool).creationCode)
            )
        );

        address preAddress2 = address(uint160(uint256(hashPreAddress2)));

        address newPool2 = s_factory.deployPool(address(wBTC), address(USDT));
        address getTokenPairPool2 = s_factory.getTokenPairToPool(address(wBTC), address(USDT));
        assertEq(preAddress2, newPool2);
        assertEq(preAddress2, getTokenPairPool2);
        vm.stopPrank();

        /* console.logBytes32(bytes32(hashPreAddress));
        bytes memory bytecode = type(MonadexV1Pool).creationCode;
        console.logBytes32(keccak256(abi.encodePacked(bytecode))); */
    }

    function test_deployPoolwBTCUSDT() public {
        vm.startPrank(LP1);
        bytes32 salt = keccak256(abi.encodePacked(address(wBTC), address(USDT)));
        bytes32 hashPreAddress = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(s_factory), salt, keccak256(type(MonadexV1Pool).creationCode)
            )
        );
        address preAddress = address(uint160(uint256(hashPreAddress)));
        address newPool = s_factory.deployPool(address(wBTC), address(USDT));
        assertEq(preAddress, newPool);
        console.log("test_deployPoolwBTCUSDT: ", newPool);
    }

    function test_deployPoolwBTCUSDT_2() public {
        vm.startPrank(LP1);
        bytes32 salt = keccak256(abi.encodePacked(address(USDT), address(wBTC)));
        bytes32 hashPreAddress = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(s_factory), salt, keccak256(type(MonadexV1Pool).creationCode)
            )
        );
        address preAddress = address(uint160(uint256(hashPreAddress)));
        address newPool = s_factory.deployPool(address(USDT), address(wBTC));
        // assertEq(preAddress, newPool);
        console.log("test_deployPoolwBTCUSDT: ", preAddress);
    }

    function testFail_revertIfPairAlreadyExists() external deployNewPool {
        vm.prank(LP1);
        address newPool = s_factory.deployPool(address(wETH), address(DAI));
    }

    function testFail_revertIfPairUntidyExists() external deployNewPool {
        vm.prank(LP1);
        address newPool = s_factory.deployPool(address(DAI), address(wETH));
    }

    function test_deployMultiplePools() external {
        vm.startPrank(LP1);
        address[] memory tokens = new address[](4);
        tokens[0] = address(wETH);
        tokens[1] = address(wBTC);
        tokens[2] = address(USDT);
        tokens[3] = address(DAI);

        for (uint256 i = 0; i < 4; ++i) {
            s_factory.deployPool(address(SHIB), address(tokens[i]));
        }

        assert(s_factory.getTokenPairToPool(address(wETH), address(SHIB)) != address(0));
        assert(s_factory.getTokenPairToPool(address(wBTC), address(SHIB)) != address(0));
        assert(s_factory.getTokenPairToPool(address(USDT), address(SHIB)) != address(0));
        assert(s_factory.getTokenPairToPool(address(DAI), address(SHIB)) != address(0));

        vm.stopPrank();
    }

    function testFail_revertIfOneTokenNotAuth() external {
        vm.startPrank(LP1);
        address[] memory tokens = new address[](5);
        tokens[0] = address(wETH);
        tokens[1] = address(wBTC);
        tokens[2] = address(DANGER);
        tokens[3] = address(USDT);
        tokens[4] = address(DAI);

        for (uint256 i = 0; i < 5; ++i) {
            s_factory.deployPool(address(SHIB), address(tokens[i]));
        }

        assert(s_factory.getTokenPairToPool(address(wETH), address(SHIB)) == address(0));

        vm.stopPrank();
    }
}
