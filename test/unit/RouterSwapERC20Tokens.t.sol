// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
//  FUNCTIONS TESTED: 2
//  *IMPORTANT* THIS TEST HAS RAFFLE TICKETS SET TO FALSE
//  THE PORPUSE IS TEST THE SWAPS
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. swapExactTokensForTokens()
//  2. swapTokensForExactTokens()
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

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RouterSwapERC20Tokens is Test, Deployer, RouterAddLiquidity {
    // ----------------------------------
    //    swapExactTokensForTokens()
    // ----------------------------------

    function test_swap10K_DAIForwBTC() public {
        // 1. Lets add some cash to the pool:
        test_secondSupplyAddDAI_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(DAI), address(wBTC));

        uint256 balance_swapper1_DAI = DAI.balanceOf(swapper1);
        uint256 balance_swapper1_wBTC = wBTC.balanceOf(swapper1);
        uint256 balance_pool_DAI = DAI.balanceOf(pool);
        uint256 balance_pool_wBTC = wBTC.balanceOf(pool);

        console.log("**  test_swap10K_DAIForwBTC() **");
        console.log("initial user balance DAI: ", balance_swapper1_DAI / 1e18); // 1000000e18
        console.log("initial user user wBTC: ", balance_swapper1_wBTC / 1e18); // 1000000e18
        console.log("initial pool user DAI: ", balance_pool_DAI / 1e18); // 300Ke18
        console.log("initial pool user wBTC: ", balance_pool_wBTC / 1e18); // 60Ke18

        /**
         * SWAP START *
         */
        // 1. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(wBTC);

        // 2. User don't want raffle tickets: This is not the objetive of this test
        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: false,
            multiplier: MonadexV1Types.Multipliers.Multiplier1,
            minimumTicketsToReceive: 0
        });

        // 3. swap
        vm.startPrank(swapper1);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokens(
            ADD_10K, 1, path, swapper1, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        // 4. check the swap, not the formula yet @audit-note
        console.log("");
        console.log("final balance user DAI: ", DAI.balanceOf(swapper1) / 1e18); // 990000e18
        console.log("final balance user wBTC: ", wBTC.balanceOf(swapper1) / 1e18); // 1001929e18
        console.log("");
        console.log("");
        assertEq(DAI.balanceOf(swapper1), balance_swapper1_DAI - ADD_10K);
    }

    // ----------------------------------
    //    swapTokensForExactTokens()
    // ----------------------------------
    function test_swapwBTCToObtain10K_DAI() public {
        // 1. Lets add some cash to the pool:
        test_secondSupplyAddDAI_WBTC();

        // 2. A few checks before the start:
        address pool = s_factory.getTokenPairToPool(address(DAI), address(wBTC));

        uint256 balance_swapper1_DAI = DAI.balanceOf(swapper1);
        uint256 balance_swapper1_wBTC = wBTC.balanceOf(swapper1);
        uint256 balance_pool_DAI = DAI.balanceOf(pool);
        uint256 balance_pool_wBTC = wBTC.balanceOf(pool);

        console.log("**  test_swapwBTCToObtain10K_DAI() **");
        console.log("initial user balance DAI: ", balance_swapper1_DAI / 1e18); // 1000000e18
        console.log("initial user user wBTC: ", balance_swapper1_wBTC / 1e18); // 1000000e18
        console.log("initial pool user DAI: ", balance_pool_DAI / 1e18); // 300Ke18
        console.log("initial pool user wBTC: ", balance_pool_wBTC / 1e18); // 60Ke18

        /**
         * SWAP START *
         */
        // 1. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(wBTC);
        path[1] = address(DAI);

        // 2. User don't want raffle tickets: This is not the objetive of this test
        MonadexV1Types.PurchaseTickets memory purchaseTickets = MonadexV1Types.PurchaseTickets({
            purchaseTickets: false,
            multiplier: MonadexV1Types.Multipliers.Multiplier1,
            minimumTicketsToReceive: 0
        });

        // 3. swap
        /*
         * @audit-note check this error if approve ADD_100k
         * ailing tests:
         * Encountered 1 failing test in test/unit/RouterSwapERC20Tokens.t.sol:RouterSwapERC20Tokens
         * [FAIL. Reason: MonadexV1Router__ExcessiveInputAmount(40080160320641282565131 [4.008e22], 10000000000000000000000 [1e22])] test_swapwBTCToObtain10K_DAI() (gas: 3018974)
         */
        vm.startPrank(swapper1);
        wBTC.approve(address(s_router), ADD_50K);
        s_router.swapTokensForExactTokens(
            600e18, ADD_50K, path, swapper1, block.timestamp, purchaseTickets
        );
        vm.stopPrank();

        // 4. check the swap, not the formula yet @audit-note
        console.log("");
        console.log("final balance user DAI: ", DAI.balanceOf(swapper1) / 1e18); // 1000600e18
        console.log("final balance user wBTC: ", wBTC.balanceOf(swapper1) / 1e18); // 959919
        console.log("final pool user DAI: ", DAI.balanceOf(pool) / 1e18); // 299400e18
        console.log("final pool user wBTC: ", wBTC.balanceOf(pool) / 1e18); // 100080e18
        console.log("");
        console.log("");
        assertEq(DAI.balanceOf(swapper1), balance_swapper1_DAI + 600 ether);
    }
}
