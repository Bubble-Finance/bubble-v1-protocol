// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: InitializeConstructorsArgs
//  1. Governor Initialize.
//     @audit-note Governor is currently under development and has no effect on the protocol.
//  2. Factory Initialize.
//  3. Raffle Initialize.
//     @audit-note contract InitializeOracle is a mock contract of pyth protocol.
//                 every pyth function go there.
//     @audit-note every token should be whiteListed for raffles.
//                 wNomad native is whiteListed by default in the deployment.
//  4. Router Initialize.
// ----------------------------------

import { Test, console } from "./../../lib/forge-std/src/Test.sol";
import { MonadexV1Types } from "./../../src/library/MonadexV1Types.sol";

import { InitializeTokens } from "./InitializeTokens.sol";

import { InitializePythV2 } from "test/baseHelpers/InitializePythV2.sol";

import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { MockEntropy } from "test/baseHelpers/MockEntropy.sol";
import { MockEntropyContract } from "test/baseHelpers/MockEntropyContract.sol";

contract InitializeConstructorsArgs is Test, InitializeTokens, InitializePythV2 {
    // -------------------------------------------
    //  Governor Initialize
    // -------------------------------------------
    uint48 public s_initialVotingDelay = uint48(7200);
    uint32 public s_initialVotingPeriod = uint32(50400);
    uint256 public s_initialProposalThreshold = 50e18;
    uint256 public s_quorum = 4;

    uint256 public s_initialSupply = 1_000_000e18; // MDX token initial supply

    uint256 public s_minDelay = 2 days;
    address[] public s_proposers;
    address[] public s_executors;

    // -------------------------------------------
    //     Factory Initialize
    // -------------------------------------------
    MonadexV1Types.Fraction public s_protocolFee;
    MonadexV1Types.Fraction[5] public s_feeTiers;

    // ** Fee Tiers for LPs => swaps
    uint256 public constant NUMERATOR1 = 1;
    uint256 public constant NUMERATOR2 = 2;
    uint256 public constant NUMERATOR3 = 3;
    uint256 public constant NUMERATOR4 = 4;
    uint256 public constant NUMERATOR5 = 5;
    uint256 public constant DENOMINATOR_1000 = 1000;
    uint256 public constant DENOMINATOR_100 = 100;
    // ** Protocol fees for Protocol => swaps
    uint256 public constant PROTOCOL_NUMERATOR = 1;
    uint256 public constant PROTOCOL_DENOMINATOR = 5;

    function initializeFactoryConstructorArgs() public {
        s_protocolFee = MonadexV1Types.Fraction({
            numerator: PROTOCOL_NUMERATOR,
            denominator: PROTOCOL_DENOMINATOR
        });

        MonadexV1Types.Fraction[5] memory feeTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_1000 }), // 0.1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_1000 }), // 0.2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_1000 }), // 0.3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_1000 }), // 0.4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_1000 }) // 0.4%
        ];

        for (uint256 count = 0; count < 5; ++count) {
            s_feeTiers[count] = feeTiers[count];
        }
    }

    // -------------------------------------------
    //     Oracle Pyth Prices Initialize
    // -------------------------------------------
    InitializePythV2 public s_initializePyth;
    MonadexV1Types.PriceFeedConfig[] public s_priceFeedConfigs;

    function initializePythMockAndPrices() public {
        s_entropyContract = address(s_pythPriceFeedContract);

        s_initializePyth = new InitializePythV2();

        // bytes[] memory updateData = s_initializePyth.createEthUpdate();
    }

    // -------------------------------------------
    //     Oracle Pyth Entropy Initialize
    // -------------------------------------------
    MockEntropy mock; // provider and entropy;
    bytes32 userRandomNumber = 0x85f0ce7392d4ff75162f550c8a2679da7b3c39465d126ebae57b4bb126423d3a;

    address public s_entropyContract;
    address public s_entropyProvider;

    MockEntropyContract mockEntropy;

    function initializeEntropy() public {
        mock = new MockEntropy(userRandomNumber);
        // mockEntropy = new MockEntropyContract(address(mock), address(mock)); // not needed

        s_entropyProvider = address(mock);
        s_entropyContract = address(mock);
    }

    // -------------------------------------------
    //     Raffle Initialize
    // -------------------------------------------
    address[] public s_supportedTokens;
    MonadexV1Types.Fraction[3] public s_multipliersToPercentages;
    MonadexV1Types.Fraction[3] public s_winningPortions;
    uint256 public s_minimumParticipants;

    uint256 public constant WINNING_PORTTIONS_1 = 45;
    uint256 public constant WINNING_PORTTIONS_2 = 20;
    uint256 public constant WINNING_PORTTIONS_3 = 5;

    function initializeRaffleConstructorArgs() public {
        // ADDING  s_wNative AS AUTHORISED TOKEN //
        s_supportedTokens.push(s_wNative);

        MonadexV1Types.PriceFeedConfig memory wethConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        s_priceFeedConfigs.push(wethConfig);
        // FINISHED ADDING  s_wNative AS AUTHORISED TOKEN //

        MonadexV1Types.Fraction[3] memory multipliersToPercentages = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }),
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }),
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 })
        ];

        for (uint256 count = 0; count < 3; ++count) {
            s_multipliersToPercentages[count] = multipliersToPercentages[count];
        }

        MonadexV1Types.Fraction[3] memory winningPortions = [
            MonadexV1Types.Fraction({ numerator: WINNING_PORTTIONS_1, denominator: DENOMINATOR_100 }),
            MonadexV1Types.Fraction({ numerator: WINNING_PORTTIONS_2, denominator: DENOMINATOR_100 }),
            MonadexV1Types.Fraction({ numerator: WINNING_PORTTIONS_3, denominator: DENOMINATOR_100 })
        ];

        for (uint256 count = 0; count < 3; ++count) {
            s_winningPortions[count] = winningPortions[count];
        }

        s_minimumParticipants = 10;
    }

    // -------------------------------------------
    //     Router Initialize
    // -------------------------------------------
    address s_wNative = address(wMonad);
}
