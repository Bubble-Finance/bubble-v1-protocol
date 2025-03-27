// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title CampaignsScriptBase.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Provides config for campaigns deployment.
abstract contract CampaignsScriptBase {
    uint256 public s_minimumTokenTotalSupply;
    uint256 public s_minimumVirutalNativeTokenReserve;
    uint256 public s_minimumNativeTokenAmountToRaise;
    BubbleV1Types.Fraction public s_fee;
    uint256 public s_tokenCreatorReward;
    uint256 public s_liquidityMigrationFee;
    address public s_monadexV1Router;
    address public s_wNative;
    address public s_vault;

    function _initializeCampaignsConstructorArgs() internal {
        // placeholder values, change on each run

        s_minimumTokenTotalSupply = 1_000 ether;
        s_minimumVirutalNativeTokenReserve = 0.01 ether;
        s_minimumNativeTokenAmountToRaise = 0.1 ether;
        s_fee = BubbleV1Types.Fraction({ numerator: 1, denominator: 10 });
        s_tokenCreatorReward = 0.01 ether;
        s_liquidityMigrationFee = 0.01 ether;
        s_monadexV1Router = address(1);
        s_wNative = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;
        s_vault = 0xE5261f469bAc513C0a0575A3b686847F48Bc6687;
    }
}
