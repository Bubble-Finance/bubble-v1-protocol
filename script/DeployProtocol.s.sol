// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";

import { MonadexV1Factory } from "../src/core/MonadexV1Factory.sol";
import { MDX } from "../src/governance/MDX.sol";
import { MonadexV1Governor } from "../src/governance/MonadexV1Governor.sol";
import { MonadexV1Timelock } from "../src/governance/MonadexV1Timelock.sol";
import { MonadexV1Types } from "../src/library/MonadexV1Types.sol";
import { MonadexV1Raffle } from "../src/raffle/MonadexV1Raffle.sol";
import { MonadexV1Router } from "../src/router/MonadexV1Router.sol";

contract DeployProtocol is Script {
    // factory constructor args
    address public s_protocolTeamMultisig;
    MonadexV1Types.Fee public s_protocolFee;
    MonadexV1Types.Fee[5] public s_feeTiers;

    // raffle constructor args
    MonadexV1Types.Fee[3] public s_multipliersToPercentages;
    MonadexV1Types.Fee[3] public s_winningPortions;
    address[] public s_supportedTokens;
    uint256 public s_rangeSize;

    // router constructor args
    address public s_wNative;

    // MDX token constructor args
    uint256 public s_initialSupply;

    // timelock constructor args
    uint256 public s_minDelay;
    address[] public s_proposers;
    address[] public s_executors;

    // governor constructor args
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

    function initializeFactoryConstructorArgs() public {
        // the values below are bound to change

        s_protocolTeamMultisig = makeAddr("protocol team  multi-sig");

        s_protocolFee = MonadexV1Types.Fee({ numerator: 1, denominator: 5 });

        MonadexV1Types.Fee[5] memory feeTiers = [
            MonadexV1Types.Fee({ numerator: 1, denominator: 1000 }), // tier 1, 0.1%
            MonadexV1Types.Fee({ numerator: 2, denominator: 1000 }), // tier 2, 0.2%
            MonadexV1Types.Fee({ numerator: 3, denominator: 1000 }), // tier 3 (default), 0.3%
            MonadexV1Types.Fee({ numerator: 4, denominator: 1000 }), // tier 4, 0.4%
            MonadexV1Types.Fee({ numerator: 5, denominator: 1000 }) // tier 5, 0.5%
        ];
        for (uint256 count = 0; count < 5; ++count) {
            s_feeTiers[count] = feeTiers[count];
        }
    }

    function initializeRouterConstructorArgs() public {
        s_wNative = makeAddr("wNative");
    }

    function initializeRaffleConstructorArgs() public {
        // the values below are bound to change

        MonadexV1Types.Fee[3] memory multipliersToPercentages = [
            MonadexV1Types.Fee({ numerator: 5, denominator: 1000 }), // multiplier 1, 0.5% of swap amount
            MonadexV1Types.Fee({ numerator: 1, denominator: 100 }), // multiplier 2, 1% of swap amount
            MonadexV1Types.Fee({ numerator: 2, denominator: 100 }) // multiplier 3, 2% of swap amount
        ];
        for (uint256 count = 0; count < 3; ++count) {
            s_multipliersToPercentages[count] = multipliersToPercentages[count];
        }

        MonadexV1Types.Fee[3] memory winningPortions = [
            MonadexV1Types.Fee({ numerator: 45, denominator: 100 }), // tier 1, 45% to 1 winner
            MonadexV1Types.Fee({ numerator: 20, denominator: 100 }), // tier 2, 20% to 2 winners
            MonadexV1Types.Fee({ numerator: 5, denominator: 100 }) // tier 3, 5% to 3 winners
        ];
        for (uint256 count = 0; count < 3; ++count) {
            s_winningPortions[count] = winningPortions[count];
        }

        // more tokens like USDC, etc must be supported later on
        s_supportedTokens.push(s_wNative);

        s_rangeSize = 1e3;
    }

    function initializeGovernanceConstructorArgs() public {
        // the values below are bound to change

        // for MDX
        s_initialSupply = 1_000_000e18;

        // for timelock
        s_minDelay = 2 days; // the time after which a proposal can be executed after it has passed

        // for governor
        // Monad may have large number of blocks per second, unlike Ethereum which has a block per 12 sec
        // we might need to inflate these values quite a bit
        s_initialVotingDelay = uint48(7200); // the time after which voting begins, in blocks
        s_initialVotingPeriod = uint32(50400); // the time duration for which the voting lasts, in blocks
        s_initialProposalThreshold = 50e18; // the amount of MDX you must hold before creating a proposal
        s_quorum = 4; // pretty standard, Compund uses this as well
    }

    function run() public {
        initializeFactoryConstructorArgs();
        initializeRouterConstructorArgs();
        initializeRaffleConstructorArgs();
        initializeGovernanceConstructorArgs();

        vm.startBroadcast();
        s_factory = new MonadexV1Factory(s_protocolTeamMultisig, s_protocolFee, s_feeTiers);
        s_raffle = new MonadexV1Raffle(
            s_multipliersToPercentages, s_winningPortions, s_supportedTokens, s_rangeSize
        );
        s_router = new MonadexV1Router(address(s_factory), address(s_raffle), s_wNative);
        s_raffle.initializeRouterAddress(address(s_router));

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
}
