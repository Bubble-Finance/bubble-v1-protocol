// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: ERC20Launchable
//  FUNCTIONS TESTED: 2
//  This test check all the get functions of the Token Launchable contract.
// ----------------------------------

// ----------------------------------
// TEST: ERC20Launchable
// [PASS] testIslaunch() (gas: 18804)
// [PASS] testLaunch() (gas: 16918)
// [PASS] testMint() (gas: 14023)
// -----------------------------------


import { Test, console } from "./../../lib/forge-std/src/Test.sol";


import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import {Deployer2} from "../baseHelpers/Deployer2.sol";
import {ERC20Launchable} from "../../src/campaigns/ERC20Launchable.sol";
import { InitializeActors } from "../baseHelpers/InitializeActors.sol";

contract testLaunchableERC20 is Test,  InitializeActors {
    ERC20Launchable s_ERC20Launchable;
    string name = "Oscar MEME";
    string symbol = "OMEME";
    uint256 totalSupply = 100_000;
    function setUp() public {
        string memory _name = "Oscar MEME";
        string memory _symbol = "OMEME";
        uint256 _totalSupply = 100_000;
        vm.startPrank(creator1);
        s_ERC20Launchable = new ERC20Launchable(_name, _symbol, _totalSupply);
        vm.stopPrank();
    }
    function testMint() public view {
        uint256 balance = s_ERC20Launchable.balanceOf(creator1);
        console.log("Balance of creator1:", balance);
    }
    function testLaunch() public {
        vm.startPrank(creator1);
        s_ERC20Launchable.launch();
        vm.stopPrank();
    }
    function testIslaunch() public {
        vm.startPrank(creator1);
        s_ERC20Launchable.launch();
        vm.stopPrank();
        bool isItLaunched = s_ERC20Launchable.isLaunched();
        assertEq(isItLaunched, true);
    }

}