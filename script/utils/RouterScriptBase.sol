// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title RouterScriptBase.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Provides config for router deployment.
abstract contract RouterScriptBase {
    address public s_wNative;

    function _initializeRouterConstructorArgs() internal {
        // placeholder value, change on each run

        s_wNative = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;
    }
}
