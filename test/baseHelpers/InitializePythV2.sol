// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: InitializePythV2
//  FUNCTIONS: 3
//  This contract uses the standard Mock Pyth to creare prices
//  for the protocol
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------
import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Pyth Contracts Imports
// --------------------------------

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { MockPyth } from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

contract InitializePythV2 is Test {
    // --------------------------------------------
    //  MOCK Pyth.SOL
    //  https://pyth.network/developers/price-feed-ids
    //  wMOnad = Crypto.WETH/USD      0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6
    //  Crypto.WBTC/USD	0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33
    //  Crypto.DAI/USD	0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd
    //  Crypto.USDT/USD	0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b
    //  Crypto.SHIB/USD	0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a
    // --------------------------------------------
    bytes32 cryptoMonadUSD = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
    bytes32 cryptowBTCUSD = 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;
    bytes32 cryptoDAIUSD = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
    bytes32 cryptoUSDTUSD = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
    bytes32 cryptoSHIBUSD = 0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a;

    MockPyth s_pythPriceFeedContract;

    constructor() {
        /*
         * MockPyth constructor(uint _validTimePeriod, uint _singleUpdateFeeInWei):
         * uint singleUpdateFeeInWei = 1;
         * uint validTimePeriod = 60 // Uses to set a price no older tha 60 secs.
         */
        s_pythPriceFeedContract = new MockPyth(60, 1);
    }

    function createEthUpdate() public view returns (bytes[] memory) {
        bytes[] memory updateData = new bytes[](5);
        updateData[0] = s_pythPriceFeedContract.createPriceFeedUpdateData(
            cryptoMonadUSD,
            2400 * 100000, // price
            10 * 100000, // confidence
            -5, // exponent
            2400 * 100000, // emaPrice
            10 * 100000, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        updateData[1] = s_pythPriceFeedContract.createPriceFeedUpdateData(
            cryptowBTCUSD,
            6694393168987, // price
            7408528286, // confidence
            -8, // exponent
            6703066300000, // emaPrice
            8104350500, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        updateData[2] = s_pythPriceFeedContract.createPriceFeedUpdateData(
            cryptoDAIUSD,
            99984529, // price
            225894, // confidence
            -8, // exponent
            99986299, // emaPrice
            227157, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        updateData[3] = s_pythPriceFeedContract.createPriceFeedUpdateData(
            cryptoUSDTUSD,
            99993992, // price
            177642, // confidence
            -8, // exponent
            99985931, // emaPrice
            149516, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        updateData[4] = s_pythPriceFeedContract.createPriceFeedUpdateData(
            cryptoSHIBUSD,
            181756, // price
            241, // confidence
            -10, // exponent
            182053, // emaPrice
            261, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        return updateData;
    }
}
