// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SmartLottery} from "../src/Lottery.sol";

contract DeployLottery is Script {
    function run() external returns (SmartLottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        SmartLottery lottery = new SmartLottery(
            config.vrfCoordinatorV2,
            config.subscriptionId,
            config.keyHash,
            config.callbackGasLimit,
            config.minimumTicketPrice
        );
        vm.stopBroadcast();
        return (lottery, helperConfig);
    }
}
