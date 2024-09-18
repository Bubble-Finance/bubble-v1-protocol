// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Factory
//  FUNCTIONS TESTED: 6
//  This test check all the sets and side features.
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract PythTest is Test, Deployer {
    function test_pythAddressAndOthers() public view {
        console2.log("adddress s_pythPriceFeedContract: ", address(s_pythPriceFeedContract));
        console2.log("adddress s_initializePyth: ", address(s_initializePyth));
    }

    function test_getPriceNoOlderThan() public payable {
        vm.startPrank(LP1);
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        PythStructs.Price memory price =
            s_pythPriceFeedContract.getPriceNoOlderThan(cryptoMonadUSD, 60);

        vm.stopPrank();
    }

    function test_getPrice() public payable {
        vm.startPrank(LP1);
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        PythStructs.Price memory price = s_pythPriceFeedContract.getPrice(cryptoMonadUSD);

        vm.stopPrank();
    }
}
