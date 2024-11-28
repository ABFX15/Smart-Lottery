// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from
    "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFCoordinatorV2Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title SmartLottery
 * @notice A decentralized lottery using Chainlink VRF
 */
contract SmartLottery is VRFConsumerBaseV2Plus {
    /* Errors */
    error SmartLottery__NotEnoughFunds();
    error SmartLottery__InvalidTicketPrice();
    error SmartLottery__LotteryNotExists();
    error SmartLottery__LotteryExpired();
    error SmartLottery__WrongState();
    error SmartLottery__NoEntrants();
    error SmartLottery__TransferFailed();

    /* Types */
    enum LotteryState {
        OPEN,
        CALCULATING_WINNER,
        CLOSED
    }

    struct Lottery {
        uint256 ticketPrice;
        uint256 expiration;
        address[] entrants;
        LotteryState state;
        uint256 prizePool;
    }

    /* State Variables */
    mapping(uint256 => Lottery) private s_lotteries;
    mapping(uint256 => uint256) private s_requestIdToLotteryId;

    // VRF Config
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;

    uint256 public immutable i_minimumTicketPrice;

    /* Events */
    event LotteryCreated(uint256 indexed lotteryId, uint256 ticketPrice, uint256 expiration);
    event PlayerEntered(uint256 indexed lotteryId, address indexed player);
    event WinnerPicked(uint256 indexed lotteryId, address indexed winner, uint256 prize);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 minimumTicketPrice
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_minimumTicketPrice = minimumTicketPrice;
    }

    function createLottery(uint256 lotteryId, uint256 ticketPrice, uint256 duration) external {
        if (ticketPrice < i_minimumTicketPrice) {
            revert SmartLottery__InvalidTicketPrice();
        }
        if (s_lotteries[lotteryId].state != LotteryState.CLOSED && s_lotteries[lotteryId].expiration != 0) {
            revert SmartLottery__WrongState();
        }

        s_lotteries[lotteryId] = Lottery({
            ticketPrice: ticketPrice,
            expiration: block.timestamp + duration,
            entrants: new address[](0),
            state: LotteryState.OPEN,
            prizePool: 0
        });

        emit LotteryCreated(lotteryId, ticketPrice, block.timestamp + duration);
    }

    function enterLottery(uint256 lotteryId) external payable {
        Lottery storage lottery = s_lotteries[lotteryId];
        if (lottery.state != LotteryState.OPEN) revert SmartLottery__WrongState();
        if (block.timestamp >= lottery.expiration) revert SmartLottery__LotteryExpired();
        if (msg.value < lottery.ticketPrice) revert SmartLottery__NotEnoughFunds();

        lottery.entrants.push(msg.sender);
        lottery.prizePool += msg.value;

        emit PlayerEntered(lotteryId, msg.sender);
    }

    function pickWinner(uint256 lotteryId) external {
        Lottery storage lottery = s_lotteries[lotteryId];
        if (lottery.state != LotteryState.OPEN) revert SmartLottery__WrongState();
        if (lottery.entrants.length == 0) revert SmartLottery__NoEntrants();

        lottery.state = LotteryState.CALCULATING_WINNER;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            3, // numConfirmations
            i_callbackGasLimit,
            1 // numWords
        );
        s_requestIdToLotteryId[requestId] = lotteryId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 lotteryId = s_requestIdToLotteryId[requestId];
        Lottery storage lottery = s_lotteries[lotteryId];

        uint256 winnerIndex = randomWords[0] % lottery.entrants.length;
        address winner = lottery.entrants[winnerIndex];
        uint256 prize = lottery.prizePool;

        lottery.state = LotteryState.CLOSED;
        lottery.prizePool = 0;

        (bool success,) = winner.call{value: prize}("");
        if (!success) revert SmartLottery__TransferFailed();

        emit WinnerPicked(lotteryId, winner, prize);
    }

    /* View Functions */
    function getLottery(uint256 lotteryId)
        external
        view
        returns (uint256 ticketPrice, uint256 expiration, uint256 numEntrants, LotteryState state, uint256 prizePool)
    {
        Lottery storage lottery = s_lotteries[lotteryId];
        return (lottery.ticketPrice, lottery.expiration, lottery.entrants.length, lottery.state, lottery.prizePool);
    }

    function getEntrants(uint256 lotteryId) external view returns (address[] memory) {
        return s_lotteries[lotteryId].entrants;
    }
}
