// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {SmartLottery} from "../src/Lottery.sol";

contract LotteryTest is Test {
    SmartLottery public lottery;

    address public user = makeAddr("user");
    uint256 public constant STARTING_BALANCE =  10 ether;
    uint256 public constant TICKET_PRICE = 1 ether;

    // VRF Configuration
    address vrfCoordinatorV2 = makeAddr("vrfCoordinator");
    uint64 subscriptionId = 1;
    bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 100000;

    function setUp() public {
        lottery = new SmartLottery(vrfCoordinatorV2, subscriptionId, keyHash, callbackGasLimit);
        vm.deal(user, STARTING_BALANCE);
    }
}
