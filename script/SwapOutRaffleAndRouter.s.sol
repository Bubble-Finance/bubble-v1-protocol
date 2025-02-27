// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { RaffleScriptBase } from "./utils/RaffleScriptBase.sol";
import { RouterScriptBase } from "./utils/RouterScriptBase.sol";
import { Utils } from "./utils/Utils.sol";
import { MonadexV1Factory } from "@src/core/MonadexV1Factory.sol";
import { MonadexV1Types } from "@src/library/MonadexV1Types.sol";
import { MonadexV1Raffle } from "@src/raffle/MonadexV1Raffle.sol";
import { MonadexV1Router } from "@src/router/MonadexV1Router.sol";

/// @title SwapOutRaffleAndRouter.
/// @author Monadex Labs -- mgnfy-view.
/// @notice Deploys raffle and router contracts.
contract SwapOutRaffleAndRouter is RaffleScriptBase, RouterScriptBase, Utils, Script {
    MonadexV1Factory public s_factory;
    MonadexV1Raffle public s_raffle;
    MonadexV1Router public s_router;

    function setUp() public {
        s_factory = MonadexV1Factory(0xd829C1d3649dBc3fd96d3d22500eF33A46daae46);

        _initializeRaffleConstructorArgs();
        _initializeRouterConstructorArgs();
    }

    function run() public returns (MonadexV1Raffle, MonadexV1Router) {
        vm.startBroadcast();
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

        return (s_raffle, s_router);
    }
}
