// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Raffle
//  FUNCTIONS TESTED: 7
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. initializeBubbleV1Router()
//  2. supportToken()
//  3. removeToken()
//  4. setWinningPortions()
//  5. setMinimumNftsToBeMintedEachEpoch()
//  6. enterRaffle()
//  7. requestRandomNumber()
//  8. claimTierWinnings()
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console2 } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Bubble Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";
import { RaffleSetInitialSwaps } from "test/unit/RaffleSetInitialSwaps.t.sol";

import { BubbleV1Library } from "src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "src/library/BubbleV1Types.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RaffleRunTheRaffle is Test, Deployer, RaffleSetInitialSwaps {
    // --------------------------------
    //    initializeBubbleV1Router()
    // --------------------------------
    function testFail_changingTheRouterAddress() public {
        // Router address is set during the deploy:
        address routerAddress = s_raffle.getBubbleV1Router();
        assertEq(routerAddress, address(s_router));

        // We can not change it after the deploy!
        vm.prank(protocolTeamMultisig);
        s_raffle.initializeBubbleV1Router(address(s_factory));
    }

    // --------------------------------
    //    supportToken()
    // --------------------------------
    function test_supportTokenGetSupported() public {
        vm.startPrank(protocolTeamMultisig);
        BubbleV1Types.PriceFeedConfig[4] memory _pythPriceFeedConfig = [
            // BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoMonadUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptowBTCUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoDAIUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoUSDTUSD, noOlderThan: 60 }),
            BubbleV1Types.PriceFeedConfig({ priceFeedId: cryptoSHIBUSD, noOlderThan: 60 })
        ];

        s_raffle.supportToken(address(wBTC), _pythPriceFeedConfig[0]);
        s_raffle.supportToken(address(DAI), _pythPriceFeedConfig[1]);
        s_raffle.supportToken(address(USDT), _pythPriceFeedConfig[2]);
        s_raffle.supportToken(address(SHIB), _pythPriceFeedConfig[3]);

        address[] memory supportedTokens = s_raffle.getSupportedTokens();
        assertEq(address(wMonad), supportedTokens[0]);
        assertEq(address(wBTC), supportedTokens[1]);
        assertEq(address(DAI), supportedTokens[2]);
        assertEq(supportedTokens.length, 5);
        vm.stopPrank();
    }

    // --------------------------------
    //    removeToken()
    // --------------------------------
    function test_succesfullyRemoveToken() public {
        test_supportTokenGetSupported();

        assertEq(s_raffle.isSupportedToken(address(DAI)), true);
        vm.prank(protocolTeamMultisig);
        s_raffle.removeToken(address(DAI));
        assertEq(s_raffle.isSupportedToken(address(DAI)), false);
    }

    // --------------------------------
    //    requestRandomNumber()
    // --------------------------------
    function test_easyRequestRandomNumber() public {
        test_startSwappinfUsingExistingPools();

        uint256 usersThisEpoch = s_raffle.getNftsMintedEachEpoch(1);

        console2.log("");
        console2.log("*** RUN THE RAFFLE ***");
        console2.log("NFTS minted this Epoch: ", usersThisEpoch);

        vm.warp(block.timestamp + 7 days);

        uint128 requestFee = mock.getFee(address(mock));
        s_raffle.requestRandomNumber(userRandomNumber);
    }

    // --------------------------------
    //    claimTierWinnings()
    // --------------------------------
    function test_easyClaimTierWinnings() public {
        // 1. Set initial conditions
        test_easyRequestRandomNumber();

        uint256 epochToClaim = s_raffle.getCurrentEpoch() - 1;
        console2.log("epoch: ", epochToClaim);

        uint256[] memory randomNumber = s_raffle.getEpochToRandomNumbersSupplied(epochToClaim);

        console2.log(
            "** Entropy contract store 6 random numbers calculated with the PYTH original random number ***"
        );
        console2.log("randomNumber[0]: ", randomNumber[0]);
        console2.log("randomNumber[1]: ", randomNumber[1]);
        console2.log("randomNumber[2]: ", randomNumber[2]);
        console2.log("randomNumber[3]: ", randomNumber[3]);
        console2.log("randomNumber[4]: ", randomNumber[4]);
        console2.log("randomNumber[5]: ", randomNumber[5]);

        // 2. Determine the winner
        // After check, the winner is swapper10

        vm.startPrank(swapper10);
        console2.log("swapper10", swapper10);

        BubbleV1Types.RaffleClaim memory _claim = BubbleV1Types.RaffleClaim({
            tier: BubbleV1Types.Tiers.TIER1,
            epoch: epochToClaim,
            tokenId: 10
        });

        console2.log("swapper10 balance: ", DAI.balanceOf(address(swapper10)));
        console2.log("Raffle balance: ", DAI.balanceOf(address(s_raffle)) / 1e18);

        s_raffle.claimTierWinnings(_claim);

        console2.log("swapper10 balance: ", DAI.balanceOf(swapper10));
        console2.log("Raffle balance After: ", DAI.balanceOf(address(s_raffle)) / 1e18);
    }
}
