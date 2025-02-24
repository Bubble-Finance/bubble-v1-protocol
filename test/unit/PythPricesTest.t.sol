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

import { IERC20Metadata } from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract PythPricesTest is Test, Deployer {
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
            s_pythPriceFeedContract.getPriceNoOlderThan(cryptoDAIUSD, 60);

        vm.stopPrank();
    }

    function test_priceForDAI() public payable {
        // 1. Check current price in Pyth:
        vm.startPrank(LP1);
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        PythStructs.Price memory price = s_pythPriceFeedContract.getPrice(cryptoDAIUSD);

        console2.log("price: ", price.price);
        console2.log("expo: ", price.expo);

        // 2. Calculate the current change rate for 300 DAI:
        uint256 amount = 300e18;
        uint256 tokenDecimals = IERC20Metadata(address(DAI)).decimals();
        console2.log("tokenDecimals: ", tokenDecimals);

        uint256 totalValueInUsd = MonadexV1Library.totalValueInUsd(amount, price, 6, tokenDecimals);

        console2.log("totalValueInUsd: ", totalValueInUsd / 1e6);

        vm.stopPrank();
    }

    /* function _convertToUsd(address _token, uint256 _amount) internal view returns (uint256) {
        MonadexV1Types.PriceFeedConfig memory config = s_tokenToPriceFeedConfig[_token];
        PythStructs.Price memory price =
            s_pythPriceFeedContract.getPriceNoOlderThan(config.priceFeedId, config.noOlderThan);
        uint256 tokenDecimals = IERC20Metadata(_token).decimals();
        console2.log("tokenDecimals: ", tokenDecimals);

        return MonadexV1Library.totalValueInUsd(_amount, price, 6, tokenDecimals);
    } */
}
