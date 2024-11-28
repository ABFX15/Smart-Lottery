// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {SmartLottery} from "../src/Lottery.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DeployLottery} from "../script/DeployLottery.s.sol";

contract LotteryTest is Test {
    SmartLottery public lottery;
    HelperConfig public helperConfig;

    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant TICKET_PRICE = 1 ether;
    uint256 public constant INVALID_PRICE = 0.1 ether;
    uint256 public constant LOTTERY_ID = 1;

    // VRF Configuration
    address vrfCoordinatorV2;
    uint64 subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit;

    function setUp() public {
        DeployLottery deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();
        vm.deal(user, STARTING_BALANCE);
        vm.prank(lottery.owner());
        lottery.transferOwnership(user);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinatorV2 = config.vrfCoordinatorV2;
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;
    }

    modifier lotteryCreated() {
        vm.prank(user);
        lottery.createLottery(LOTTERY_ID, TICKET_PRICE, 1 days);
        _;
    }

    function testRevertsIfInvalidTicketPrice() public {
        vm.startPrank(user);
        vm.expectRevert(SmartLottery.SmartLottery__InvalidTicketPrice.selector);
        lottery.createLottery(LOTTERY_ID, INVALID_PRICE, block.timestamp + 1 days);
    }

    function testRevertsIfLotteryExpired() public lotteryCreated {
        vm.startPrank(user);
        vm.warp(block.timestamp + 1 days + 1 seconds);
        vm.expectRevert(SmartLottery.SmartLottery__LotteryExpired.selector);
        lottery.enterLottery{value: TICKET_PRICE}(LOTTERY_ID);
        vm.stopPrank();
    }

    function testCanCreateLottery() public {
        vm.startPrank(user);
        uint256 duration = 1 days;
        uint256 expectedExpiration = block.timestamp + duration;
        lottery.createLottery(LOTTERY_ID, TICKET_PRICE, duration);
        vm.stopPrank();
        (uint256 ticketPrice, uint256 actualExpiration, uint256 numEntrants,, uint256 prizePool) =
            lottery.getLottery(LOTTERY_ID);

        assertEq(ticketPrice, TICKET_PRICE);
        assertEq(actualExpiration, expectedExpiration, "Expiration timestamp mismatch");
        assertEq(numEntrants, 0);
        assertEq(prizePool, 0);
    }

    function testRevertsIfNotEnoughFunds() public lotteryCreated {
        vm.startPrank(user2);
        vm.deal(user2, STARTING_BALANCE);
        vm.expectRevert(SmartLottery.SmartLottery__NotEnoughFunds.selector);
        lottery.enterLottery{value: INVALID_PRICE}(LOTTERY_ID);
        vm.stopPrank();
    }

    function testCanEnterLottery() public lotteryCreated {
        vm.startPrank(user2);
        vm.deal(user2, STARTING_BALANCE);
        lottery.enterLottery{value: TICKET_PRICE}(LOTTERY_ID);
        vm.stopPrank();

        (
            , // ticketPrice
            , // expiration
            uint256 numEntrants,
            , // state
            uint256 prizePool
        ) = lottery.getLottery(LOTTERY_ID);

        address[] memory entrants = lottery.getEntrants(LOTTERY_ID);

        assertEq(prizePool, TICKET_PRICE);
        assertEq(numEntrants, 1);
        assertEq(entrants[0], user2);
    }

    function testRaffleAddsPlayerWhenTheyEnter() public lotteryCreated {
        vm.startPrank(user2);
        vm.deal(user2, STARTING_BALANCE);
        lottery.enterLottery{value: TICKET_PRICE}(LOTTERY_ID);
        address playerEntered = lottery.getEntrants(LOTTERY_ID)[0];
        vm.stopPrank();
        assertEq(playerEntered, user2, "Player should be user2");
    }
}
