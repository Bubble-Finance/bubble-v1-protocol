// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Raffle
//  FUNCTIONS TESTED: 29
//  This test check all the get functions of the monadex raffle contract.
// ----------------------------------

// ----------------------------------
//  TEST:
// ** ROUTER **
/*
[PASS] testClaimRaffle() (gas: 2234726)
[PASS] testConvertToUsd() (gas: 223237)
[PASS] testEnterRaffle() (gas: 495327)
[PASS] testGetEntropy() (gas: 9463)
[PASS] testGetEpochDuration() (gas: 9307)
[PASS] testGetLastDrawTimestamp() (gas: 11040)
[PASS] testGetMinimumNFTToBeMinted() (gas: 11018)
[PASS] testGetMinimumNftsToBeMintedEachEpoch() (gas: 11042)
[PASS] testGetNextTokenId() (gas: 1716684)
[PASS] testGetNftToRange() (gas: 494760)
[PASS] testGetPyth() (gas: 9406)
[PASS] testGetTiers() (gas: 9244)
[PASS] testGetTokenAmountCollectedInEpouch() (gas: 2125359)
[PASS] testGetTokenPriceConfig() (gas: 134157)
[PASS] testHasUserClaimedTierWinningsForEpoch() (gas: 2189687)
[PASS] testInitializeMonadexV1Router() (gas: 13454)
[PASS] testIsTokenSupported() (gas: 140014)
[PASS] testRemoveSingleToken() (gas: 107988)
[PASS] testSetUp() (gas: 211)
[PASS] testSupportMultipleToken() (gas: 131705)
[PASS] testSupportToken() (gas: 137273)
[PASS] testThisShitOut() (gas: 4262)
[PASS] test_RequestRandomNumber() (gas: 1943713)
[PASS] testgetCurrentSequenceNumber() (gas: 1920469)
[PASS] testgetMonadexV1Router() (gas: 17003)
[PASS] testgetUserNftsEachEpoch() (gas: 2112653)
[PASS] testgetWinnersInTier1() (gas: 9399)
[PASS] testgetWinnersInTier2() (gas: 9313)
[PASS] testgetWinnersInTier3() (gas: 9248)
*/
// ----------------------------------

import { Test, console, console2 } from "./../../lib/forge-std/src/Test.sol";


import { MonadexV1Types } from "./../../src/library/MonadexV1Types.sol";
import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";
import {Deployer2} from "../baseHelpers/Deployer2.sol";
import {MonadexV1Raffle} from "../../src/raffle/MonadexV1Raffle.sol";
import {IPythMock} from "../baseHelpers/IPythMock.sol";
import {MockEntropy} from "../baseHelpers/MockEntropy.sol";
import {InitializePythV2} from "../baseHelpers/InitializePythV2.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
contract V1RaffleTest is Test, Deployer2{

    bytes32 initialRandomNumber = bytes32("InitialRandomNumber");
    MockEntropy _mockEntropy = new MockEntropy(initialRandomNumber);
    //IPythMock IpythMock = new IPythMock();
    //InitializePythV2 mockPyth = new InitializePythV2();
    function testSetUp() public {
    }

    function testInitializeMonadexV1Router() public {
        vm.expectRevert();
        s_raffle.initializeMonadexV1Router(address(s_router));
    }
    function testgetMonadexV1Router() public{
        vm.startPrank(protocolTeamMultisig);
        address router = s_raffle.getMonadexV1Router();
        console.log("Router address is", router);
        vm.stopPrank();
    }

    function _supportToken() public {
        MonadexV1Types.PriceFeedConfig memory mockConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6, // Dummy ID
            noOlderThan: 300 // 5 minutes
        });

        vm.startPrank(protocolTeamMultisig);
        s_raffle.supportToken(address(wMonad), mockConfig);
        MonadexV1Types.PriceFeedConfig memory expectedConfig = s_raffle.getTokenPriceFeedConfig(address(wMonad));
        assertEq(mockConfig.priceFeedId, expectedConfig.priceFeedId);
        vm.stopPrank();
        vm.expectRevert();
        s_raffle.supportToken(address(wMonad), mockConfig);
    }

    function testIsTokenSupported() public {
        _supportToken();
        bool isSupported = s_raffle.isSupportedToken(address(wMonad));
        assertEq(isSupported, true);
    }

    function _supportMultipleToken() public {
        // MonadexV1Types.PriceFeedConfig memory mockConfig = MonadexV1Types.PriceFeedConfig({
        //     priceFeedId: 0xe62df6bde7bf0000000000000000000000000000000000000000000000000000, // Dummy ID for ETH/USD
        //     noOlderThan: 300 // 5 minutes
        // });
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });

        vm.startPrank(protocolTeamMultisig);
        vm.stopPrank();
        vm.startPrank(protocolTeamMultisig);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();
    }
    function testSupportToken() public {
        _supportToken();
    }
    function testSupportMultipleToken() public {
        _supportMultipleToken();
    }
    function testRemoveSingleToken() public {
        _supportMultipleToken();
        vm.startPrank(protocolTeamMultisig);
        s_raffle.removeToken(address(USDC));
        bool isRemoved = s_raffle.isSupportedToken(address(USDC));
        assertEq(isRemoved, false);
        vm.stopPrank();
    }
    
    function testEnterRaffle() public {
        bytes32 _USDCPriceFeedId =  0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        console.log("price Feed config created...");
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        //InitializePythV2.createEthUpdate();
        console.log("set price created ....");
        vm.startPrank(protocolTeamMultisig);
        console.log("protocolTeamMultisig created");
        s_raffle.supportToken(address(USDC), mockConfig2);
        console.log("supported token created ...");
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        uint256 tokenId = s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        assertEq(s_raffle.ownerOf(tokenId), swapper1);
        }
    function test_RequestRandomNumber() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        console.log("mock config created...");
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        console.log("starting Prank...");
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        console.log("entering raffles....");
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        // skip by a week 
        vm.warp(block.timestamp + 1 weeks);

        bytes32 raffleRandomNumber = bytes32("SykeThatsTheWrongNumber");
        s_raffle.requestRandomNumber{value: 0}(raffleRandomNumber);

        uint256 lastEpouch = s_raffle.getCurrentEpoch() - 1;
        console.log("currentEpouch: ", lastEpouch);
        uint256[] memory randomNumbers = s_raffle.getEpochToRandomNumbersSupplied(lastEpouch);
        
         // Log all random numbers
        for(uint i = 0; i < randomNumbers.length; i++) {
            console.log("Random number", i, ":", randomNumbers[i]);
        }
    }

    function testClaimRaffle() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();
        uint256 amount = USDC.balanceOf(address(s_router));
        console.log("amount in router contract",amount);
        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        // skip by a week 
        vm.warp(block.timestamp + 1 weeks);
        deal(address(USDC), address(s_raffle), type(uint256).max);
        bytes32 raffleRandomNumber = bytes32("SykeThatsTheWrongNumber");
        s_raffle.requestRandomNumber{value: 0}(raffleRandomNumber);

        uint256 lastEpouch = s_raffle.getCurrentEpoch() - 1;
        console.log("currentEpouch: ", lastEpouch);
        uint256[] memory randomNumbers = s_raffle.getEpochToRandomNumbersSupplied(lastEpouch);
        

        //2- calculate the total range of the deposited amount
        uint totalNFTRange = s_raffle.getNftsMintedEachEpoch(lastEpouch);
        uint epouchToRange = s_raffle.getEpochToRangeEndingPoint(lastEpouch);
        //uint distance = s_raffle.getDistance();
        //console.log("total distance", distance);
        console.log("total NFT Range is", totalNFTRange);
        console.log("epouch to range is", epouchToRange);
        uint randomNumberLength = randomNumbers.length;
        console.log ("randomNumberLength:", randomNumberLength);
        for (uint i = 0; i < randomNumberLength; i++) {
            console.log(" loop of randomNumber reached"); 
            uint hitPoint = randomNumbers[i] % epouchToRange;
            console.log("Random number", i, "hit point:", hitPoint);

             //Determine which NFT range this hit
            if(hitPoint < Fifty_Dollars) console.log("Hit NFT #1");
            else if(hitPoint < (Fifty_Dollars * 2)) console.log("Hit NFT #2");
            else if(hitPoint < (Fifty_Dollars *3 )) console.log("Hit NFT #3");
            else if(hitPoint < (Fifty_Dollars * 4)) console.log("Hit NFT #4");
            else if(hitPoint < (Fifty_Dollars * 5)) console.log("Hit NFT #5");
            else if(hitPoint < (Fifty_Dollars * 6)) console.log("Hit NFT #6");
            else console.log("Hit NFT #7");

            // Log which tier this corresponds to
            if(i == 0) console.log("This is for Tier 1");
            else if(i == 1 || i == 2) console.log("This is for Tier 2");
            else console.log("This is for Tier 3");
        }
        // Log token amounts collected for the epoch
        uint256 usdcCollected = s_raffle.getTokenAmountCollectedInEpoch(lastEpouch, address(USDC));
        console.log("USDC collected in epoch:", usdcCollected);

        // Log actual USDC balance of raffle contract
        uint256 raffleUsdcBalance = USDC.balanceOf(address(s_raffle));
        console.log("Raffle contract USDC balance:", raffleUsdcBalance);
        

        MonadexV1Types.RaffleClaim memory claim = MonadexV1Types.RaffleClaim({
            tier: MonadexV1Types.Tiers.TIER3,
            epoch: lastEpouch,
            tokenId: 4
        });
        MonadexV1Types.Winnings[] memory winningsDetails = s_raffle.getWinnings(claim);
        uint lengthP = winningsDetails.length;
        console.log("Winning details length", lengthP);
        console.log("Winnings for token 0:", winningsDetails[0].amount);
        console.log("Winnings for token 0 Addr", winningsDetails[0].token);
        console.log("USDC address", address(USDC));
        uint256 initialBalance = USDC.balanceOf(swapper4);
        console.log("initial balance",initialBalance);
        // Check owner of the token
        address tokenOwner = s_raffle.ownerOf(4);
        console.log("Token 4 owner:", tokenOwner);
        console.log("Swapper4 address:", swapper4);
        vm.startPrank(swapper4);
        
        s_raffle.claimTierWinnings(claim);
        // cheaking that the final is more than the starting 
        uint256 finalBalance1 = USDC.balanceOf(swapper1);
        uint256 finalBalance2 = USDC.balanceOf(swapper2);
        uint256 finalBalance3 = USDC.balanceOf(swapper3);
        uint256 finalBalance4 = USDC.balanceOf(swapper4);
        uint finalBalance5 = USDC.balanceOf(swapper5);

        console.log("final balance",finalBalance1);
        console.log("final balance",finalBalance2);
        console.log("final balance",finalBalance3);
        console.log("final balance",finalBalance4);
        console.log("final balance",finalBalance5);
        console.log("final balance6",USDC.balanceOf(swapper6));
        console.log("final balance7",USDC.balanceOf(swapper7));

        assertTrue(finalBalance4 > initialBalance);
        vm.stopPrank();
        // try claim again theive, haha
        vm.startPrank(swapper4);
        vm.expectRevert();
        s_raffle.claimTierWinnings(claim);
        vm.stopPrank();
    }

    function testHasUserClaimedTierWinningsForEpoch() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        //bytes32 _ETHPriceFeedId = 0xe62df6bde7bf0000000000000000000000000000000000000000000000000000;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        // skip by a week 
        vm.warp(block.timestamp + 1 weeks);
        deal(address(USDC), address(s_raffle), TOKEN_1);
        bytes32 raffleRandomNumber = bytes32("SykeThatsTheWrongNumber");
        s_raffle.requestRandomNumber{value: 0}(raffleRandomNumber);

        uint256 lastEpouch = s_raffle.getCurrentEpoch() - 1;
        //console.log("currentEpouch: ", lastEpouch);
        uint256[] memory randomNumbers = s_raffle.getEpochToRandomNumbersSupplied(lastEpouch);
        

        //2- calculate the total range of the deposited amount
        uint totalNFTRange = s_raffle.getNftsMintedEachEpoch(lastEpouch);
        uint epouchToRange = s_raffle.getEpochToRangeEndingPoint(lastEpouch);
        console.log("total NFT Range is", totalNFTRange);
        console.log("epouch to range is", epouchToRange);

        for (uint i = 0; i < randomNumbers.length; i++) {
            uint hitPoint = randomNumbers[i] % epouchToRange;
            console.log("Random number", i, "hit point:", hitPoint);

             //Determine which NFT range this hit
            if(hitPoint < Fifty_Dollars) console.log("Hit NFT #1");
            else if(hitPoint < (Fifty_Dollars * 2)) console.log("Hit NFT #2");
            else if(hitPoint < (Fifty_Dollars *3 )) console.log("Hit NFT #3");
            else if(hitPoint < (Fifty_Dollars * 4)) console.log("Hit NFT #4");
            else if(hitPoint < (Fifty_Dollars * 5)) console.log("Hit NFT #5");
            else if(hitPoint < (Fifty_Dollars * 6)) console.log("Hit NFT #6");
            else console.log("Hit NFT #7");

            // Log which tier this corresponds to
            if(i == 0) console.log("This is for Tier 1");
            else if(i == 1 || i == 2) console.log("This is for Tier 2");
            else console.log("This is for Tier 3");
        }

        MonadexV1Types.RaffleClaim memory claim = MonadexV1Types.RaffleClaim({
            tier: MonadexV1Types.Tiers.TIER1,
            epoch: lastEpouch,
            tokenId: 4
        });

        vm.startPrank(swapper4);
        s_raffle.claimTierWinnings(claim);
        vm.stopPrank();

        bool HasClaimed = s_raffle.hasUserClaimedTierWinningsForEpoch(4, lastEpouch, MonadexV1Types.Tiers.TIER1 );
        assertEq(HasClaimed, true);
    }

    function testGetTokenAmountCollectedInEpouch() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        // skip by a week 
        vm.warp(block.timestamp + 1 weeks);
        deal(address(USDC), address(s_raffle), TOKEN_1);
        bytes32 raffleRandomNumber = bytes32("SykeThatsTheWrongNumber");
        s_raffle.requestRandomNumber{value: 0}(raffleRandomNumber);

        uint256 lastEpouch = s_raffle.getCurrentEpoch() - 1;
        //console.log("currentEpouch: ", lastEpouch);
        s_raffle.getEpochToRandomNumbersSupplied(lastEpouch);
        

        //2- calculate the total range of the deposited amount
        uint totalNFTRange = s_raffle.getNftsMintedEachEpoch(lastEpouch);
        uint epouchToRange = s_raffle.getEpochToRangeEndingPoint(lastEpouch);
        console.log("total NFT Range is", totalNFTRange);
        console.log("epouch to range is", epouchToRange);
        uint amountCollected = s_raffle.getTokenAmountCollectedInEpoch(lastEpouch, address(USDC));
        assertEq(amountCollected, Fifty_Dollars * 7);
    }
    function testgetUserNftsEachEpoch() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        // skip by a week 
        vm.warp(block.timestamp + 1 weeks);
        deal(address(USDC), address(s_raffle), TOKEN_1);
        bytes32 raffleRandomNumber = bytes32("SykeThatsTheWrongNumber");
        s_raffle.requestRandomNumber{value: 0}(raffleRandomNumber);

        uint256 lastEpouch = s_raffle.getCurrentEpoch() - 1;

        uint[] memory NftEachEpouch = s_raffle.getUserNftsEachEpoch(swapper1, lastEpouch);
        assertEq(NftEachEpouch[0], 1);
    }
    function testGetEntropy() public view{
        address entropy = s_raffle.getEntropyContract();
        console.log("Entropy address is", entropy);
    }
    function testGetEpochDuration() public view {
        uint EpouchDuration = s_raffle.getEpochDuration();
        console.log("Epoch Duration is", EpouchDuration);
    }
    function testGetTiers() public view {
        uint Tiers = s_raffle.getTiers();
        console.log("Tiers is", Tiers);
    }
    function testgetWinnersInTier1() public view {
        uint WinnersInTier1 = s_raffle.getWinnersInTier1();
        console.log("Winners in Tier 1 is", WinnersInTier1);
    }
    function testgetWinnersInTier2() public view {
        uint WinnersInTier2 = s_raffle.getWinnersInTier2();
        console.log("Winners in Tier 2 is", WinnersInTier2);
    }
    function testgetWinnersInTier3() public view {
        uint WinnersInTier3 = s_raffle.getWinnersInTier3();
        console.log("Winners in Tier 3 is", WinnersInTier3);
    }

    function testGetPyth() public view {
        address pyth = s_raffle.getPyth();
        console.log("Pyth address is", pyth);
    }
    function testGetNftToRange() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        uint256 tokenId = s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        assertEq(s_raffle.ownerOf(tokenId), swapper1);

        uint256[] memory NFTRange = s_raffle.getNftToRange(tokenId);
        assertEq(NFTRange[0], 0);
        assertEq(NFTRange[1], Fifty_Dollars);
    }

    function testGetMinimumNftsToBeMintedEachEpoch() public view {
        uint MinNftMinted = s_raffle.getMinimumNftsToBeMintedEachEpoch();
        assertEq(MinNftMinted, 10);
    }
    function testGetLastDrawTimestamp() public view {
        uint lastTime = s_raffle.getLastDrawTimestamp();
        assertEq(lastTime, 1);
    }
    function testGetNextTokenId() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        uint256 tokenId = s_raffle.getNextTokenId();
        assertEq(tokenId, 7);
    }
    function testGetMinimumNFTToBeMinted() public view {
        uint256 NFTToBeMinted = s_raffle.getMinimumNftsToBeMintedEachEpoch();
        assertEq(NFTToBeMinted, 10);
    }
    function testgetCurrentSequenceNumber() public {
        bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
            priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
            noOlderThan: 300 // 5 minutes
        });
        // using usdc of decimal 6
        IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
        vm.startPrank(protocolTeamMultisig);
        s_raffle.setMinimumNftsToBeMintedEachEpoch(7);
        s_raffle.supportToken(address(USDC), mockConfig2);
        vm.stopPrank();

        vm.startPrank(address(s_router));
        uint256 Fifty_Dollars = 50 * (10 ** 6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper1);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper2);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper3);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper4);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper5);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper6);
        s_raffle.enterRaffle(address(USDC), Fifty_Dollars, swapper7);
        vm.stopPrank();

        // skip by a week 
        vm.warp(block.timestamp + 1 weeks);

        bytes32 raffleRandomNumber = bytes32("SykeThatsTheWrongNumber");
        s_raffle.requestRandomNumber{value: 0}(raffleRandomNumber);
    }
    function testGetTokenPriceConfig() public {
        MonadexV1Types.PriceFeedConfig memory mockConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0xe62df6bde7bf0000000000000000000000000000000000000000000000000000, // Dummy ID
            noOlderThan: 300 // 5 minutes
        });

        //address token =  ;
        vm.startPrank(protocolTeamMultisig);
        s_raffle.supportToken(address(wMonad), mockConfig);
        MonadexV1Types.PriceFeedConfig memory expectedConfig = s_raffle.getTokenPriceFeedConfig(address(wMonad));
        assertEq(mockConfig.priceFeedId, expectedConfig.priceFeedId);
        vm.stopPrank();
    }
    // note uncomment this out, set convertTousd function to public, for unit testing purposes.
    // function testConvertToUsd() public {

    //     address getPyth = s_raffle.getPyth();
    //     console.log("Pyth address in contract:", getPyth);
    //     console.log("Mock address:", address(IpythMock));
    //     require (getPyth == address(IpythMock), "Pyth address is not the same as the mock address");
    //     bytes32 _USDCPriceFeedId =  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    //     MonadexV1Types.PriceFeedConfig memory mockConfig2 = MonadexV1Types.PriceFeedConfig({
    //         priceFeedId: _USDCPriceFeedId, // Dummy ID for usdc/usd
    //         noOlderThan: 300 // 5 minutes
    //     });
    //     // using usdc of decimal 6
    //     IpythMock.setPrice(_USDCPriceFeedId, 1000000, -6, 5000); // Price = 1 USD, Confidence = 0.005 USD
    //     verifyPythMock();
    //     PythStructs.Price memory storedPrice = IpythMock.getPrice(_USDCPriceFeedId);
    //     console.log("Stored price:", int(storedPrice.price));
    //     console.log("Stored expo:", int(storedPrice.expo));
    
    //     vm.startPrank(protocolTeamMultisig);
    //     //s_raffle.setPyth(address(IpythMock));
    //     s_raffle.supportToken(address(USDC), mockConfig2);
    //     vm.stopPrank();

    //     vm.startPrank(address(s_router));
    //     uint256 Fifty_Dollars = 50 * (10 ** 6);
    //     uint actualFifty = s_raffle._convertToUsd(address(USDC), Fifty_Dollars );
    //     assertEq(actualFifty, Fifty_Dollars);
    // }
    // Add this to your test contract
    function verifyPythMock() public view {
        bytes32 testId = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    
        // Test direct storage access
        PythStructs.Price memory priceA = IpythMock.getPrice(testId);
        console.log("Direct price:", int(priceA.price));
    
        // Test age-based retrieval
        PythStructs.Price memory priceB = IpythMock.getPriceNoOlderThan(testId, 300);
        console.log("Age-based price:", int(priceB.price));
    }

    function getLocalErrorSelector() public pure returns (bytes4) {
        string memory error = ("MonadexV1Router__DeadlinePasssed(uint256,uint256)");
        console.log("error to test:", error);
        return bytes4(keccak256("MonadexV1Router__DeadlinePasssed(uint256,uint256)"));
    }

    function testThisShitOut() public pure {
        bytes4 getTest = getLocalErrorSelector();

        // Use console2.logBytes32 for bytes32 values
        console2.logBytes32(bytes32(getTest));
        // Or convert to uint256
        //console2.log("Local Selector:", uint256(bytes32(getTest)));
    }
}