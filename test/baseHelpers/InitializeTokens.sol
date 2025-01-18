// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: InitializeTokens
//  1. Deploy Tokens to be used on TESTS.
//  2. TokenMock: Standard contract for tokens wETH, wBTC, USDT, DAI, SHIB
//  3. WNative: Standard contract for wrapped Native (Monad)
//  4. DangerousToken: Crazy contract that will try to stole the user funds.
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { console } from "./../../lib/forge-std/src/console.sol";

import { DangerousToken } from "../utils/DangerousToken.sol";
import { TokenMock } from "../utils/TokenMock.sol";
import { WNative } from "../utils/WNative.sol";

contract InitializeTokens {
    // --------------------------------
    //    CONSTANTS
    // --------------------------------
    uint256 constant USDC_1 = 1e6;
    uint256 constant USDC_10K = 1e10; // 1e4 = 10K tokens with 6 decimals
    uint256 constant USDC_100K = 1e11; // 1e5 = 100K tokens with 6 decimals
    uint256 constant TOKEN_1 = 1e18;
    uint256 constant TOKEN_10K = 1e22; // 1e4 = 10K tokens with 18 decimals
    uint256 constant TOKEN_100K = 1e23; // 1e5 = 100K tokens with 18 decimals
    uint256 constant TOKEN_1M = 1e24; // 1e6 = 1M tokens with 18 decimals
    uint256 constant TOKEN_10M = 1e25; // 1e7 = 10M tokens with 18 decimals
    uint256 constant TOKEN_100M = 1e26; // 1e8 = 100M tokens with 18 decimals
    uint256 constant TOKEN_10B = 1e28; // 1e10 = 10B tokens with 18 decimals

    // --------------------------------
    //    CONTRACTS INIT
    // --------------------------------
    TokenMock wETH = new TokenMock("wETH token", "wETH", 18); // Pegged to ETH
    TokenMock wBTC = new TokenMock("wBTC  token", "wBTC", 18); // Pegged to BTC
    TokenMock USDT = new TokenMock("USDT token", "USDT", 8); // a 8 decimals stable coin
    TokenMock DAI = new TokenMock("DAI token", "DAI", 18); // a 18 decimals stable coin
    TokenMock SHIB = new TokenMock("Shiba token", "SHIB", 18); //a 18 decimals shitty coin
    DangerousToken DANGER = new DangerousToken("Danger token", "DANGER", 18); // really risky token
    WNative wMonad = new WNative(); // wrapped Monad
}
