// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { RaffleScriptBase } from "@script/utils/RaffleScriptBase.sol";
import { RouterScriptBase } from "@script/utils/RouterScriptBase.sol";
import { Utils } from "@script/utils/Utils.sol";
import { BubbleV1Factory } from "@src/core/BubbleV1Factory.sol";
import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";
import { BubbleV1Raffle } from "@src/raffle/BubbleV1Raffle.sol";
import { BubbleV1Router } from "@src/router/BubbleV1Router.sol";

/// @title SwapOutRaffleAndRouter.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Deploys raffle and router contracts.
contract SwapOutRaffleAndRouter is RaffleScriptBase, RouterScriptBase, Utils, Script {
    BubbleV1Factory public s_factory;
    BubbleV1Raffle public s_raffle;
    BubbleV1Router public s_router;

    function setUp() public {
        s_factory = BubbleV1Factory(0xd829C1d3649dBc3fd96d3d22500eF33A46daae46);

        _initializeRaffleConstructorArgs();
        _initializeRouterConstructorArgs();
    }

    function run() public returns (BubbleV1Raffle, BubbleV1Router) {
        vm.startBroadcast();
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

        return (s_raffle, s_router);
    }
}
