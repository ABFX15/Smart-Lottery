// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title SmartLottery
 * @author Adam Cryptab
 * @notice A decentralized lottery system using Chainlink VRF for verifiable randomness
 * @dev Inherits from VRFConsumerBaseV2Plus to integrate Chainlink's VRF functionality
 * @notice This contract allows users to:
 * - Enter lotteries by purchasing tickets
 * - Automatically and fairly select winners using Chainlink VRF
 * - Create and manage multiple concurrent lottery instances
 */
contract SmartLottery is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SmartLottery__NotEnoughFunds();
    error SmartLottery__LotteryClosed();
    error SmartLottery__TransferFailed();
    error SmartLottery__NotOperator();
    error SmartLottery__InvalidTicketPrice();
    error SmartLottery__LotteryNotExists();
    error SmartLottery__LotteryExpired();
    error SmartLottery__LotteryAlreadyExists();
    error SmartLottery__NoEntrants();

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/
    enum LotteryState {
        OPEN,
        CALCULATING_WINNER,
        CLOSED
    }

    struct Lottery {
        uint256 lotteryId;
        uint256 ticketPrice;
        uint256 expiration;
        address operator;
        address payable winner;
        LotteryState state;
        address payable[] entrants;
        uint256 prizePool;
    }

    /*//////////////////////////////////////////////////////////////
                                VARIABLES
    //////////////////////////////////////////////////////////////*/
    // VRF Variables
    address private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    mapping(uint256 => Lottery) private s_lotteries;
    mapping(uint256 => uint256) private s_requestIdToLotteryId;
    uint256 private s_currentLotteryId;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event LotteryCreated(
        uint256 indexed lotteryId,
        uint256 ticketPrice,
        uint256 expiration,
        address operator
    );
    event PlayerEntered(uint256 indexed lotteryId, address indexed player);
    event WinnerPicked(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event RequestedRandomness(uint256 indexed lotteryId, uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    // Only the lottery operator can perform certain actions
    modifier onlyOperator(uint256 _lotteryId) {
        if (msg.sender != s_lotteries[_lotteryId].operator) {
            revert SmartLottery__NotOperator();
        }
        _;
    }

    // Check if the lottery exists
    modifier lotteryExists(uint256 _lotteryId) {
        if (s_lotteries[_lotteryId].operator == address(0)) {
            revert SmartLottery__LotteryNotExists();
        }
        _;
    }

    // Check if the lottery is open
    modifier lotteryOpen(uint256 _lotteryId) {
        if (s_lotteries[_lotteryId].state != LotteryState.OPEN) {
            revert SmartLottery__LotteryClosed();
        }
        if (block.timestamp >= s_lotteries[_lotteryId].expiration) {
            revert SmartLottery__LotteryExpired();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_vrfCoordinator = vrfCoordinatorV2;
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new lottery with the specified parameters
     * @param _lotteryId The ID of the new lottery
     * @param _ticketPrice The price of a single ticket in wei
     * @param _expiration The expiration timestamp of the lottery
     */
    function createLottery(
        uint256 _lotteryId,
        uint256 _ticketPrice,
        uint256 _expiration
    ) external {
        if (_ticketPrice == 0) revert SmartLottery__InvalidTicketPrice();
        if (_expiration <= block.timestamp) revert SmartLottery__LotteryExpired();
        if (s_lotteries[_lotteryId].operator != address(0)) {
            revert SmartLottery__LotteryAlreadyExists();
        }

        s_lotteries[_lotteryId] = Lottery({
            lotteryId: _lotteryId,
            ticketPrice: _ticketPrice,
            expiration: _expiration,
            operator: msg.sender,
            winner: payable(address(0)),
            state: LotteryState.OPEN,
            entrants: new address payable[](0),
            prizePool: 0
        });

        emit LotteryCreated(_lotteryId, _ticketPrice, _expiration, msg.sender);
    }

    /**
     * @notice Allows a player to enter a lottery by sending the required funds
     * @param _lotteryId The ID of the lottery to enter
     */
    function enterLottery(uint256 _lotteryId) external payable 
        lotteryExists(_lotteryId) 
        lotteryOpen(_lotteryId) 
    {
        Lottery storage lottery = s_lotteries[_lotteryId];
        if (msg.value < lottery.ticketPrice) {
            revert SmartLottery__NotEnoughFunds();
        }

        lottery.entrants.push(payable(msg.sender));
        lottery.prizePool += msg.value;

        emit PlayerEntered(_lotteryId, msg.sender);
    }

    /**
     * @notice Picks a winner for the specified lottery
     * @param _lotteryId The ID of the lottery to pick a winner for
     */
    function pickWinner(uint256 _lotteryId) external 
        lotteryExists(_lotteryId) 
        lotteryOpen(_lotteryId)
        onlyOperator(_lotteryId) 
    {
        Lottery storage lottery = s_lotteries[_lotteryId];
        if (lottery.entrants.length == 0) revert SmartLottery__NoEntrants();

        lottery.state = LotteryState.CALCULATING_WINNER;

        uint256 requestId = VRFCoordinatorV2Interface(i_vrfCoordinator).requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToLotteryId[requestId] = _lotteryId;

        emit RequestedRandomness(_lotteryId, requestId);
    }

    /**
     * @notice Callback function to handle the VRF response
     * @param requestId The ID of the request
     * @param randomWords The array of random words returned by the VRF
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 lotteryId = s_requestIdToLotteryId[requestId];
        Lottery storage lottery = s_lotteries[lotteryId];
        
        uint256 indexOfWinner = randomWords[0] % lottery.entrants.length;
        address payable winner = lottery.entrants[indexOfWinner];
        
        lottery.winner = winner;
        lottery.state = LotteryState.CLOSED;
        
        uint256 prize = lottery.prizePool;
        lottery.prizePool = 0;

        

        (bool success, ) = winner.call{value: prize}("");
        if (!success) {
            revert SmartLottery__TransferFailed();
        }
        
        emit WinnerPicked(lotteryId, winner, prize);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Retrieves the details of a specific lottery
     * @param _lotteryId The ID of the lottery to retrieve details for
     * @return ticketPrice The price of a single ticket in wei
     * @return expiration The expiration timestamp of the lottery
     * @return operator The address of the lottery operator
     * @return winner The address of the lottery winner
     * @return state The current state of the lottery
     * @return entrantsCount The number of entrants in the lottery
     * @return prizePool The prize pool of the lottery
     */
    function getLottery(uint256 _lotteryId) external view 
        returns (
            uint256 ticketPrice,
            uint256 expiration,
            address operator,
            address winner,
            LotteryState state,
            uint256 entrantsCount,
            uint256 prizePool
        ) 
    {
        Lottery storage lottery = s_lotteries[_lotteryId];
        return (
            lottery.ticketPrice,
            lottery.expiration,
            lottery.operator,
            lottery.winner,
            lottery.state,
            lottery.entrants.length,
            lottery.prizePool
        );
    }

    /**
     * @notice Retrieves the list of entrants for a specific lottery
     * @param _lotteryId The ID of the lottery to retrieve entrants for
     * @return An array of addresses representing the entrants
     */
    function getEntrants(uint256 _lotteryId) external view returns (address payable[] memory) {
        return s_lotteries[_lotteryId].entrants;
    }
}