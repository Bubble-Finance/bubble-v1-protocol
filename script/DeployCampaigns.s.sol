// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { MonadexV1Campaigns } from "@src/campaigns/MonadexV1Campaigns.sol";
import { MonadexV1Types } from "@src/library/MonadexV1Types.sol";

/// @title DeployCampaigns.
/// @author Monadex Labs -- mgnfy-view.
/// @notice Deploys the Monadex V1 Campaigns contract.
contract DeployCampaigns is Script {
    uint256 public s_minimumTokenTotalSupply;
    uint256 public s_minimumVirutalNativeTokenReserve;
    uint256 public s_minimumNativeTokenAmountToRaise;
    MonadexV1Types.Fraction public s_fee;
    uint256 public s_tokenCreatorReward;
    uint256 public s_liquidityMigrationFee;
    address public s_monadexV1Router;
    address public s_wNative;
    address public s_vault;

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

    function _initializeCampaignsConstructorArgs() internal {
        // placeholder values, change on each run

        s_minimumTokenTotalSupply = 1_000 ether;
        s_minimumVirutalNativeTokenReserve = 0.01 ether;
        s_minimumNativeTokenAmountToRaise = 0.1 ether;
        s_fee = MonadexV1Types.Fraction({ numerator: 1, denominator: 10 });
        s_tokenCreatorReward = 0.01 ether;
        s_liquidityMigrationFee = 0.01 ether;
        s_monadexV1Router = address(1);
        s_wNative = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;
        s_vault = 0xE5261f469bAc513C0a0575A3b686847F48Bc6687;
    }
}
