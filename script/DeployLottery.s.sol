// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SmartLottery} from "../src/Lottery.sol";

contract DeployLottery is Script {
    function run() public {

    }

    function deployContract() public returns (SmartLottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        SmartLottery smartLottery = new SmartLottery(config.vrfCoordinatorV2, config.subscriptionId, config.keyHash, config.callbackGasLimit);
        vm.stopBroadcast();
        return (smartLottery, helperConfig);
    }
}
