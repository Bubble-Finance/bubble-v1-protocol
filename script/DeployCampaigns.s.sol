// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { CampaignsScriptBase } from "./utils/CampaignsScriptBase.sol";
import { MonadexV1Campaigns } from "@src/campaigns/MonadexV1Campaigns.sol";

/// @title DeployCampaigns.
/// @author Monadex Labs -- mgnfy-view.
/// @notice Deploys the Monadex V1 Campaigns contract.
contract DeployCampaigns is CampaignsScriptBase, Script {
    MonadexV1Campaigns public s_campaigns;

    function setUp() public {
        _initializeCampaignsConstructorArgs();
    }

    function run() public returns (MonadexV1Campaigns) {
        vm.startBroadcast();
        s_campaigns = new MonadexV1Campaigns(
            s_minimumTokenTotalSupply,
            s_minimumVirutalNativeTokenReserve,
            s_minimumNativeTokenAmountToRaise,
            s_fee,
            s_tokenCreatorReward,
            s_liquidityMigrationFee,
            s_monadexV1Router,
            s_wNative,
            s_vault
        );
        vm.stopBroadcast();

        return s_campaigns;
    }
}
