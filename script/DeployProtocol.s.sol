// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";

import { MonadexV1Factory } from "../src/core/MonadexV1Factory.sol";
import { MDX } from "../src/governance/MDX.sol";
import { MonadexV1Governor } from "../src/governance/MonadexV1Governor.sol";
import { MonadexV1Timelock } from "../src/governance/MonadexV1Timelock.sol";
import { MonadexV1Types } from "../src/library/MonadexV1Types.sol";
import { MonadexV1Raffle } from "../src/raffle/MonadexV1Raffle.sol";
import { MonadexV1Router } from "../src/router/MonadexV1Router.sol";

/**
 * @title DeployProtocol.
 * @author Monadex Labs -- mgnfy-view.
 * @notice This contract allows you to deploy the Monadex V1 protocol with default config
 * set for Base Sepolia. If you want to deploy to any other evm-compatible chain, replace
 * the values with the correct ones.
 */
contract DeployProtocol is Script {
    // Factory constructor args
    address public s_protocolTeamMultisig;
    MonadexV1Types.Fraction public s_protocolFee;
    MonadexV1Types.Fraction[5] public s_feeTiers;

    // Raffle constructor args
    address public s_pythPriceFeedContract;
    MonadexV1Types.PriceFeedConfig[] public s_priceFeedConfigs;
    address public s_entropyContract;
    address public s_entropyProvider;
    MonadexV1Types.Fraction[3] public s_winningPortions;
    uint256 public s_minimumNftsToBeMintedEachEpoch;

    // Router constructor args
    address public s_wNative;

    // MDX token constructor args
    uint256 public s_initialSupply;

    // Timelock constructor args
    uint256 public s_minDelay;
    address[] public s_proposers;
    address[] public s_executors;

    // Governor constructor args
    uint48 public s_initialVotingDelay;
    uint32 public s_initialVotingPeriod;
    uint256 public s_initialProposalThreshold;
    uint256 public s_quorum;

    MonadexV1Factory public s_factory;
    MonadexV1Raffle public s_raffle;
    MonadexV1Router public s_router;
    MDX public s_mdx;
    MonadexV1Timelock public s_timelock;
    MonadexV1Governor public s_governor;

    function run() public {
        _initializeFactoryConstructorArgs();
        _initializeRouterConstructorArgs();
        _initializeRaffleConstructorArgs();
        _initializeGovernanceConstructorArgs();

        vm.startBroadcast();
        s_factory = new MonadexV1Factory(s_protocolTeamMultisig, s_protocolFee, s_feeTiers);

        s_raffle = new MonadexV1Raffle(
            s_pythPriceFeedContract,
            s_entropyContract,
            s_entropyProvider,
            s_minimumNftsToBeMintedEachEpoch,
            s_winningPortions
        );

        s_router = new MonadexV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeMonadexV1Router(address(s_router));
        s_raffle.supportToken(s_wNative, s_priceFeedConfigs[0]);

        s_mdx = new MDX(s_protocolTeamMultisig, s_initialSupply);
        s_timelock = new MonadexV1Timelock(s_minDelay, s_proposers, s_executors);
        s_governor = new MonadexV1Governor(
            s_mdx,
            s_timelock,
            s_initialVotingDelay,
            s_initialVotingPeriod,
            s_initialProposalThreshold,
            s_quorum
        );

        bytes32 proposerRole = s_timelock.PROPOSER_ROLE();
        bytes32 executorRole = s_timelock.EXECUTOR_ROLE();

        s_timelock.grantRole(proposerRole, address(s_governor));
        s_timelock.grantRole(executorRole, address(0));

        s_factory.transferOwnership(address(s_timelock));
        s_raffle.transferOwnership(address(s_timelock));
        vm.stopBroadcast();
    }

    function _initializeFactoryConstructorArgs() internal {
        s_protocolTeamMultisig = address(0x16aD730C8797EEC0481ba0BB32D98914073846e6);

        s_protocolFee = MonadexV1Types.Fraction({ numerator: 1, denominator: 5 });

        MonadexV1Types.Fraction[5] memory feeTiers = [
            MonadexV1Types.Fraction({ numerator: 1, denominator: 1000 }), // Tier 1, 0.1%
            MonadexV1Types.Fraction({ numerator: 2, denominator: 1000 }), // Tier 2, 0.2%
            MonadexV1Types.Fraction({ numerator: 3, denominator: 1000 }), // Tier 3 (default), 0.3%
            MonadexV1Types.Fraction({ numerator: 4, denominator: 1000 }), // Tier 4, 0.4%
            MonadexV1Types.Fraction({ numerator: 5, denominator: 1000 }) // Tier 5, 0.5%
        ];
        for (uint256 count = 0; count < 5; ++count) {
            s_feeTiers[count] = feeTiers[count];
        }
    }

    function _initializeRouterConstructorArgs() internal {
        s_wNative = address(0x4200000000000000000000000000000000000006);
    }

    function _initializeRaffleConstructorArgs() public {
        s_pythPriceFeedContract = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;

        MonadexV1Types.PriceFeedConfig memory wethConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        s_priceFeedConfigs.push(wethConfig);

        s_entropyContract = address(0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c);
        s_entropyProvider = address(0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344);

        MonadexV1Types.Fraction[3] memory winningPortions = [
            MonadexV1Types.Fraction({ numerator: 45, denominator: 100 }), // Tier 1, 45% to 1 winner
            MonadexV1Types.Fraction({ numerator: 20, denominator: 100 }), // Tier 2, 20% to 2 winners
            MonadexV1Types.Fraction({ numerator: 5, denominator: 100 }) // Tier 3, 5% to 3 winners
        ];
        for (uint256 count = 0; count < 3; ++count) {
            s_winningPortions[count] = winningPortions[count];
        }

        s_minimumNftsToBeMintedEachEpoch = 10;
    }

    function _initializeGovernanceConstructorArgs() internal {
        s_initialSupply = 1_000_000e18;

        s_minDelay = 2 days; // The time after which a proposal can be executed after it has passed

        // Monad may have large number of blocks per second, unlike Ethereum which has a block per 12 sec
        // Might need to inflate these values quite a bit
        s_initialVotingDelay = uint48(7200); // The time after which voting begins, in blocks
        s_initialVotingPeriod = uint32(50400); // The time duration for which the voting lasts, in blocks
        s_initialProposalThreshold = 50e18; // The amount of MDX you must hold before creating a proposal
        s_quorum = 4; // Pretty standard, Compund uses this as well
    }
}
