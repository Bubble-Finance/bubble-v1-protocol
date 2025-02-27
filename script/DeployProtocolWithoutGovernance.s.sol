// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { MonadexV1Factory } from "@src/core/MonadexV1Factory.sol";
import { MonadexV1Pool } from "@src/core/MonadexV1Pool.sol";
import { MonadexV1Types } from "@src/library/MonadexV1Types.sol";
import { MonadexV1Raffle } from "@src/raffle/MonadexV1Raffle.sol";
import { MonadexV1Router } from "@src/router/MonadexV1Router.sol";

/// @title DeployProtocolWithoutGovernance.
/// @author Monadex Labs -- mgnfy-view.
/// @notice This contract allows you to deploy the Monadex V1 protocol with default config
/// set for Monad testnet. It deploys the protocol components without attaching governance.
contract DeployProtocolWithoutGovernance is Script {
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

    // Utility tokens
    address public constant USDC = 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea;
    address public constant WBTC = 0xcf5a6076cfa32686c0Df13aBaDa2b40dec133F1d;
    address public constant PEPE = 0xab1fA5cc0a7dB885BC691b60eBeEbDF59354434b;

    MonadexV1Factory public s_factory;
    MonadexV1Raffle public s_raffle;
    MonadexV1Router public s_router;

    function setUp() public {
        _initializeFactoryConstructorArgs();
        _initializeRouterConstructorArgs();
        _initializeRaffleConstructorArgs();
    }

    function run() public returns (MonadexV1Factory, MonadexV1Raffle, MonadexV1Router) {
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
        s_raffle.supportToken(USDC, s_priceFeedConfigs[0]);
        s_raffle.supportToken(WBTC, s_priceFeedConfigs[1]);
        s_raffle.supportToken(PEPE, s_priceFeedConfigs[2]);
        vm.stopBroadcast();

        console.logString("Init code hash: ");
        console.logBytes32(keccak256(abi.encode(type(MonadexV1Pool).creationCode)));

        return (s_factory, s_raffle, s_router);
    }

    function _initializeFactoryConstructorArgs() internal {
        // placeholder values, change on each run

        s_protocolTeamMultisig = 0xE5261f469bAc513C0a0575A3b686847F48Bc6687;

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
        // placeholder value, change on each run

        s_wNative = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;
    }

    function _initializeRaffleConstructorArgs() public {
        // placeholder values, change on each run

        s_pythPriceFeedContract = 0x2880aB155794e7179c9eE2e38200202908C17B43;

        MonadexV1Types.PriceFeedConfig memory usdcConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        MonadexV1Types.PriceFeedConfig memory wbtcConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        MonadexV1Types.PriceFeedConfig memory pepeConfig = MonadexV1Types.PriceFeedConfig({
            priceFeedId: 0xd69731a2e74ac1ce884fc3890f7ee324b6deb66147055249568869ed700882e4,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        s_priceFeedConfigs.push(usdcConfig);
        s_priceFeedConfigs.push(wbtcConfig);
        s_priceFeedConfigs.push(pepeConfig);

        s_entropyContract = 0x36825bf3Fbdf5a29E2d5148bfe7Dcf7B5639e320;
        s_entropyProvider = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;

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
}
