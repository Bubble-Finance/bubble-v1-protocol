// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { FactoryScriptBase } from "@script/utils/FactoryScriptBase.sol";
import { RaffleScriptBase } from "@script/utils/RaffleScriptBase.sol";
import { RouterScriptBase } from "@script/utils/RouterScriptBase.sol";
import { Utils } from "@script/utils/Utils.sol";
import { BubbleV1Factory } from "@src/core/BubbleV1Factory.sol";
import { BubbleV1Pool } from "@src/core/BubbleV1Pool.sol";
import { BubbleV1Raffle } from "@src/raffle/BubbleV1Raffle.sol";
import { BubbleV1Router } from "@src/router/BubbleV1Router.sol";

/// @title DeployProtocolWithoutGovernance.
/// @author Bubble Finance -- mgnfy-view.
/// @notice This contract allows you to deploy the Bubble V1 protocol with default config
/// set for Monad testnet. It deploys the protocol components without attaching governance.
contract DeployProtocolWithoutGovernance is
    FactoryScriptBase,
    RaffleScriptBase,
    RouterScriptBase,
    Utils,
    Script
{
    BubbleV1Factory public s_factory;
    BubbleV1Raffle public s_raffle;
    BubbleV1Router public s_router;

    function setUp() public {
        _initializeFactoryConstructorArgs();
        _initializeRouterConstructorArgs();
        _initializeRaffleConstructorArgs();
    }

    function run() public returns (BubbleV1Factory, BubbleV1Raffle, BubbleV1Router) {
        vm.startBroadcast();
        s_factory = new BubbleV1Factory(s_protocolTeamMultisig, s_protocolFee, s_feeTiers);

        s_raffle = new BubbleV1Raffle(
            s_pythPriceFeedContract,
            s_entropyContract,
            s_entropyProvider,
            s_minimumNftsToBeMintedEachEpoch,
            s_winningPortions,
            s_uri
        );

        s_router = new BubbleV1Router(address(s_factory), address(s_raffle), s_wNative);

        s_raffle.initializeBubbleV1Router(address(s_router));
        s_raffle.supportToken(USDC, s_priceFeedConfigs[0]);
        s_raffle.supportToken(WBTC, s_priceFeedConfigs[1]);
        s_raffle.supportToken(PEPE, s_priceFeedConfigs[2]);
        vm.stopBroadcast();

        console.logString("Init code hash: ");
        console.logBytes32(keccak256(abi.encode(type(BubbleV1Pool).creationCode)));

        return (s_factory, s_raffle, s_router);
    }
}
