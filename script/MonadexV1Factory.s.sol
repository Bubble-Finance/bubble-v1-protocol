// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Factory } from "../src/core/MonadexV1Factory.sol";
import { Script } from "forge-std/Script.sol";

contract DeployMonadexV1Factory is Script {
    function run() external {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
