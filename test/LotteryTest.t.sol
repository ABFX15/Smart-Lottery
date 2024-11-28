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
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant TICKET_PRICE = 1 ether;
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

    // function testCreatesALottery() public {
    //     uint256 expiration = block.timestamp + 1 days;

    //     // Act: Create a lottery
    //     lottery.createLottery(LOTTERY_ID, TICKET_PRICE, expiration);

    //     // Assert: Check lottery details
    //     (
    //         uint256 ticketPrice,
    //         uint256 expiration,
    //         address operator,
    //         address winner,
    //         SmartLottery.LotteryState state,
    //         uint256 entrantsCount,
    //         uint256 prizePool
    //     ) = lottery.getLottery(LOTTERY_ID);

    //     assertEq(ticketPrice, TICKET_PRICE, "Ticket price mismatch");
    //     assertEq(expiration, block.timestamp + 1 days, "Expiration mismatch");
    //     assertEq(operator, user, "Operator mismatch");
    //     assertEq(uint8(state), uint8(SmartLottery.LotteryState.OPEN), "State mismatch");
    //     assertEq(entrantsCount, 0, "Entrants should be empty");
    //     assertEq(prizePool, 0, "Prize pool should be 0");
    // }

    function testLotteryIsOpen() public {}

    function testCanEnterLottery() public {
        vm.startPrank(user);
        lottery.createLottery(LOTTERY_ID, TICKET_PRICE, block.timestamp + 1 days);
        lottery.enterLottery{value: TICKET_PRICE}(LOTTERY_ID);
        vm.stopPrank();

        (
            , // ticketPrice
            , // expiration
            , // operator
            , // winner
            , // state
            uint256 entrantsCount,
            uint256 prizePool
        ) = lottery.getLottery(LOTTERY_ID);

        address payable[] memory entrants = lottery.getEntrants(LOTTERY_ID);

        assertEq(prizePool, TICKET_PRICE, "Prize pool should be equal to the ticket price");
        assertEq(entrantsCount, 1, "Entrants count should be 1");
        assertEq(entrants[0], user, "Entrant should be the user");
    }
}
