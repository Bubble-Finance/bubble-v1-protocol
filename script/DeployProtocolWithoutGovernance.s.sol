// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { FactoryScriptBase } from "./utils/FactoryScriptBase.sol";
import { RaffleScriptBase } from "./utils/RaffleScriptBase.sol";
import { RouterScriptBase } from "./utils/RouterScriptBase.sol";
import { Utils } from "./utils/Utils.sol";
import { MonadexV1Factory } from "@src/core/MonadexV1Factory.sol";
import { MonadexV1Pool } from "@src/core/MonadexV1Pool.sol";
import { MonadexV1Raffle } from "@src/raffle/MonadexV1Raffle.sol";
import { MonadexV1Router } from "@src/router/MonadexV1Router.sol";

/// @title DeployProtocolWithoutGovernance.
/// @author Monadex Labs -- mgnfy-view.
/// @notice This contract allows you to deploy the Monadex V1 protocol with default config
/// set for Monad testnet. It deploys the protocol components without attaching governance.
contract DeployProtocolWithoutGovernance is
    FactoryScriptBase,
    RaffleScriptBase,
    RouterScriptBase,
    Utils,
    Script
{
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
            s_winningPortions,
            s_uri
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
}
