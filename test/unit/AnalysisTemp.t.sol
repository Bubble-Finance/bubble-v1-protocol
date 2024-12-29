// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  TEST:
// ** ROUTER **
//  1. swapExactTokensForTokens()
// ** RAFFLE **
//  7. s_raffle.purchaseTickets()
// ----------------------------------

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

import { RouterAddLiquidity } from "test/unit/RouterAddLiquidity.t.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RouterSwapRaffleTrue is Test, Deployer, RouterAddLiquidity {
    // --------------------------------
    //    Modifiers
    // --------------------------------
    modifier addSupportedTokens() {
        vm.startPrank(protocolTeamMultisig);
        MonadexV1Types.PriceFeedConfig[4] memory _pythPriceFeedConfig = [
            // MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoMonadUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptowBTCUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoDAIUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoUSDTUSD, noOlderThan: 60 }),
            MonadexV1Types.PriceFeedConfig({ priceFeedId: cryptoSHIBUSD, noOlderThan: 60 })
        ];

        s_raffle.supportToken(address(wBTC), _pythPriceFeedConfig[0]);
        s_raffle.supportToken(address(DAI), _pythPriceFeedConfig[1]);
        s_raffle.supportToken(address(USDT), _pythPriceFeedConfig[2]);
        s_raffle.supportToken(address(SHIB), _pythPriceFeedConfig[3]);
        vm.stopPrank();
        _;
    }

    // --------------------------------
    //    Tests
    // -------------------------------

    // --------------------------------
    //    swapExactTokensForTokens
    // --------------------------------

    function test_checkingTheNUmber() public addSupportedTokens {
        // 1. The idea is to swap DAI for wBTC so first we need the pool with enough tokens
        // ** To add some cash to the pool, we use the contract RouterAddLiquidity
        test_secondSupplyAddDAI_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(DAI), address(wBTC));

        uint256 balance_swapper1_DAI = DAI.balanceOf(swapper1);

        /**
         * SWAP START *
         */
        // 1. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(wBTC);

        // 2. Purchase tickets = true
        bytes[] memory updateData = s_initializePyth.createEthUpdate();
        uint256 value = s_pythPriceFeedContract.getUpdateFee(updateData);
        vm.deal(address(this), value);
        s_pythPriceFeedContract.updatePriceFeeds{ value: value }(updateData);

        // PythStructs.Price memory price = s_pythPriceFeedContract.getPrice(cryptoMonadUSD);

        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: 1, denominator: 1000 }), // 0.1%
            MonadexV1Types.Fraction({ numerator: 2, denominator: 1000 }), // 0.2%
            MonadexV1Types.Fraction({ numerator: 3, denominator: 1000 }), // 0.3%
            MonadexV1Types.Fraction({ numerator: 4, denominator: 1000 }), // 0.4%
            MonadexV1Types.Fraction({ numerator: 5, denominator: 1000 }) // 0.4%
        ];

        // 2.We want tickets! we set the variable to true
        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: true,
            fractionOfSwapAmount: fractionTiers[0],
            minimumTicketsToReceive: 0,
            raffleTicketReceiver: address(swapper1)
        });

        // 3. SWAP 10K DAI for wBTC + GET Tickets
        vm.startPrank(swapper1);
        DAI.approve(address(s_router), 20000e18);
        // DAI.approve(address(s_raffle), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, purchaseTickets
        );

        vm.stopPrank();

        // 4. Checks:
        // The swapper transfer 10k + 1% ($10 => raffle buy tickets)
        assertEq(DAI.balanceOf(swapper1) / 1e18, (balance_swapper1_DAI - ADD_10K - 10e18) / 1e18);
        console.log("tickets balance: ", ERC20(s_raffle).balanceOf(swapper1));
    }
}
