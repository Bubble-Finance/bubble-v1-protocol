// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title FactoryScriptBase.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Provides config for factory deployment.
abstract contract FactoryScriptBase {
    address public s_protocolTeamMultisig;
    BubbleV1Types.Fraction public s_protocolFee;
    BubbleV1Types.Fraction[5] public s_feeTiers;

    function _initializeFactoryConstructorArgs() internal {
        // placeholder values, change on each run

        s_protocolTeamMultisig = 0xE5261f469bAc513C0a0575A3b686847F48Bc6687;

        s_protocolFee = BubbleV1Types.Fraction({ numerator: 1, denominator: 5 });

        BubbleV1Types.Fraction[5] memory feeTiers = [
            BubbleV1Types.Fraction({ numerator: 1, denominator: 1000 }), // Tier 1, 0.1%
            BubbleV1Types.Fraction({ numerator: 2, denominator: 1000 }), // Tier 2, 0.2%
            BubbleV1Types.Fraction({ numerator: 3, denominator: 1000 }), // Tier 3 (default), 0.3%
            BubbleV1Types.Fraction({ numerator: 4, denominator: 1000 }), // Tier 4, 0.4%
            BubbleV1Types.Fraction({ numerator: 5, denominator: 1000 }) // Tier 5, 0.5%
        ];
        for (uint256 count = 0; count < 5; ++count) {
            s_feeTiers[count] = feeTiers[count];
        }
    }
}
