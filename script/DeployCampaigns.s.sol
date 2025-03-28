// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { CampaignsScriptBase } from "@script/utils/CampaignsScriptBase.sol";
import { BubbleV1Campaigns } from "@src/campaigns/BubbleV1Campaigns.sol";

/// @title DeployCampaigns.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Deploys the Bubble V1 Campaigns contract.
contract DeployCampaigns is CampaignsScriptBase, Script {
    BubbleV1Campaigns public s_campaigns;

    function setUp() public {
        _initializeCampaignsConstructorArgs();
    }

    function run() public returns (BubbleV1Campaigns) {
        vm.startBroadcast();
        s_campaigns = new BubbleV1Campaigns(
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
