// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title RaffleScriptBase.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Provides config for raffle deployment.
abstract contract RaffleScriptBase {
    address public s_pythPriceFeedContract;
    BubbleV1Types.PriceFeedConfig[] public s_priceFeedConfigs;
    address public s_entropyContract;
    address public s_entropyProvider;
    BubbleV1Types.Fraction public s_fee;
    BubbleV1Types.Fraction[3] public s_winningPortions;
    uint256 public s_minimumNftsToBeMintedEachEpoch;
    string public s_uri;

    function _initializeRaffleConstructorArgs() public {
        // placeholder values, change on each run

        s_pythPriceFeedContract = 0x2880aB155794e7179c9eE2e38200202908C17B43;

        BubbleV1Types.PriceFeedConfig memory usdcConfig = BubbleV1Types.PriceFeedConfig({
            priceFeedId: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        BubbleV1Types.PriceFeedConfig memory wbtcConfig = BubbleV1Types.PriceFeedConfig({
            priceFeedId: 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        BubbleV1Types.PriceFeedConfig memory pepeConfig = BubbleV1Types.PriceFeedConfig({
            priceFeedId: 0xd69731a2e74ac1ce884fc3890f7ee324b6deb66147055249568869ed700882e4,
            noOlderThan: type(uint32).max // This is a dangerous value, make sure to not use it for mainnet
         });
        s_priceFeedConfigs.push(usdcConfig);
        s_priceFeedConfigs.push(wbtcConfig);
        s_priceFeedConfigs.push(pepeConfig);

        s_entropyContract = 0x36825bf3Fbdf5a29E2d5148bfe7Dcf7B5639e320;
        s_entropyProvider = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;

        s_fee = BubbleV1Types.Fraction({ numerator: 10, denominator: 100 });

        BubbleV1Types.Fraction[3] memory winningPortions = [
            BubbleV1Types.Fraction({ numerator: 45, denominator: 100 }), // Tier 1, 45% to 1 winner
            BubbleV1Types.Fraction({ numerator: 20, denominator: 100 }), // Tier 2, 20% to 2 winners
            BubbleV1Types.Fraction({ numerator: 5, denominator: 100 }) // Tier 3, 5% to 3 winners
        ];
        for (uint256 count = 0; count < 3; ++count) {
            s_winningPortions[count] = winningPortions[count];
        }

        s_minimumNftsToBeMintedEachEpoch = 10;

        s_uri = "https://placehold.co/400x400?text=RaffleNFT";
    }
}
