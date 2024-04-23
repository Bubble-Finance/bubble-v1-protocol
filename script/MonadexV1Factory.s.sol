// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "../lib/forge-std/src/Script.sol";
import { MonadexV1Factory } from "../src/core/MonadexV1Factory.sol";

contract DeployMonadexV1Factory is Script {
    function run() external {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
