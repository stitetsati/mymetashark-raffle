// SPDX-License-Identifier: MIT

// /\ "-./  \/\ \_\ \/\ "-./  \/\  ___/\__  _/\  __ \/\  ___\/\ \_\ \/\  __ \/\  == \/\ \/ /
// \ \ \-./\ \ \____ \ \ \-./\ \ \  __\/_/\ \\ \  __ \ \___  \ \  __ \ \  __ \ \  __<\ \  _"-.
//  \ \_\ \ \_\/\_____\ \_\ \ \_\ \_____\\ \_\\ \_\ \_\/\_____\ \_\ \_\ \_\ \_\ \_\ \_\ \_\ \_\
//   \/_/  \/_/\/_____/\/_/  \/_/\/_____/ \/_/ \/_/\/_/\/_____/\/_/\/_/\/_/\/_/\/_/ /_/\/_/\/_/

pragma solidity ^0.8.4;
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "chainlink/vrf/VRFV2WrapperConsumerBase.sol";

interface IMyMetaSharkRaffle {
    function setupRaffle(uint256 startTime, uint256 duration, uint256 ticketInterval, uint256 winnerCount) external;

    function explore(uint256[] calldata tokenIds) external;

    function claimTicket(uint256[] calldata tokenIds) external;

    function concludeCurrentRaffle() external;
}

library Array {
    function has(uint256[] memory self, uint256 value, uint256 upperbound) internal pure returns (bool) {
        for (uint256 i = 0; i < upperbound; i++) {
            if (self[i] == value) {
                return true;
            }
        }
        return false;
    }
}

contract MyMetaSharkRaffle is IMyMetaSharkRaffle, VRFV2WrapperConsumerBase, Ownable {
    using Array for uint256[];

    event TicketClaimed(uint256 indexed sharkTokenId, uint256 indexed raffleIndex, uint256 ticketNumber);
    event RaffleCreated(uint256 indexed raffleIndex, uint256 startTime, uint256 duration, uint256 ticketInterval, uint256 winnerCount);
    event Explored(uint256 indexed sharkTokenId, uint256 indexed raffleIndex, uint256 timestamp);
    event RaffleConcluded(uint256 indexed raffleIndex, uint256 randomNumber);

    struct Raffle {
        uint256 startTime;
        uint256 duration;
        uint256 ticketInterval;
        uint256 winnerCount;
        uint256 ticketsClaimed;
        uint256 randomNumber;
        uint256 vrfRequestId;
        uint256 vrfRequestEstimatedExpense;
    }
    uint256 public currentRaffleIndex = 0;
    address public myMetaShark;

    // mymetashark => raffleIndex => explorationTimestamp
    mapping(uint256 => mapping(uint256 => uint256)) public explorations;
    // mymetashark => raffleIndex => ticketNumbers
    mapping(uint256 => mapping(uint256 => uint256[])) public sharkTokenIdToRaffleTicketNumbers;

    Raffle[] public raffles;

    uint32 public immutable vrfCallbackGasLimit;

    constructor(address _myMetaShark, address _linkToken, address _vrfV2Wrapper, uint32 _vrfCallbackGasLimit) VRFV2WrapperConsumerBase(_linkToken, _vrfV2Wrapper) {
        vrfCallbackGasLimit = _vrfCallbackGasLimit;
        myMetaShark = _myMetaShark;
    }

    ///////////////////////////////
    ///////////////////////////////
    //////  ADMIN FUNCTIONS  //////
    ///////////////////////////////
    ///////////////////////////////

    /// @notice set up a new raffle
    /// @param startTime start time of the raffle
    /// @param duration duration of the raffle
    /// @param ticketInterval interval between each ticket claim
    /// @param winnerCount number of winners
    function setupRaffle(uint256 startTime, uint256 duration, uint256 ticketInterval, uint256 winnerCount) external onlyOwner {
        require(startTime > block.timestamp, "InvalidStartTime: Must be in the future");
        require(ticketInterval > 0, "InvalidTicketInterval: Must be greater than 0");
        require(duration > 0, "InvalidDuration: Must be greater than 0");
        require(ticketInterval < duration, "InvalidTicketInterval: Must be less than or equal to duration");
        require(winnerCount > 0, "InvalidWinnerCount: Must be greater than 0");

        if (raffles.length != 0) {
            Raffle storage previousRaffle = raffles[raffles.length - 1];
            uint256 previousEnd = previousRaffle.startTime + previousRaffle.duration;
            require(startTime > previousEnd, "InvalidStartTime: Must be after previous raffle end");
        }
        raffles.push(Raffle(startTime, duration, ticketInterval, winnerCount, 0, 0, 0, 0));
        emit RaffleCreated(raffles.length - 1, startTime, duration, ticketInterval, winnerCount);
    }

    ////////////////////////////////
    ////////////////////////////////
    ////// EXTERNAL FUNCTIONS //////
    ////////////////////////////////
    ////////////////////////////////

    /// @notice set MyMetaShark NFT tokens out for exploration
    /// @param tokenIds token ids to be set out to explore
    function explore(uint256[] calldata tokenIds) external {
        require(raffles.length > currentRaffleIndex, "NoRaffles: No raffles have been setup");
        Raffle storage currentRaffle = raffles[currentRaffleIndex];
        uint256 endTime = currentRaffle.startTime + currentRaffle.duration;
        require(currentRaffle.startTime <= block.timestamp, "RaffleNotStarted: Raffle has not started");
        require(endTime > block.timestamp, "RaffleEnded: Raffle has ended");
        require(endTime - block.timestamp > currentRaffle.ticketInterval, "InvalidExplorationTime: Remaining time is less than ticket interval");
        require(tokenIds.length > 0, "InvalidTokenIds: Must have at least one token id");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(IERC721(myMetaShark).ownerOf(tokenIds[i]) == msg.sender, "InvalidTokenOwner: Must own token");
            uint256 previousExplorationTimestamp = explorations[tokenIds[i]][currentRaffleIndex];
            // tokenId already explored and time elapsed >= ticket interval, help claim ticket
            if (previousExplorationTimestamp != 0) {
                uint256 timeElapsed = block.timestamp - previousExplorationTimestamp;
                if (timeElapsed >= currentRaffle.ticketInterval) {
                    _claimTicket(tokenIds[i]);
                } else {
                    revert("AlreadyExplored: Token already explored and time elapsed has not reached ticket interval");
                }
            }
            // set exploration timestamp
            explorations[tokenIds[i]][currentRaffleIndex] = block.timestamp;
            emit Explored(tokenIds[i], currentRaffleIndex, block.timestamp);
        }
    }

    /// @notice claim ticket for MyMetaShark NFT tokens
    /// @param tokenIds token ids to claim ticket for
    function claimTicket(uint256[] calldata tokenIds) external {
        require(raffles.length > currentRaffleIndex, "NoRaffles: No raffles have been setup");
        require(tokenIds.length > 0, "InvalidTokenIds: Must have at least one token id");
        Raffle storage currentRaffle = raffles[currentRaffleIndex];
        uint256 endTime = currentRaffle.startTime + currentRaffle.duration;
        require(endTime > block.timestamp, "RaffleNotEnded: Raffle has ended");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(IERC721(myMetaShark).ownerOf(tokenIds[i]) == msg.sender, "InvalidTokenOwner: Must own token");
            uint256 previousExplorationTimestamp = explorations[tokenIds[i]][currentRaffleIndex];
            require(previousExplorationTimestamp != 0, "NotExplored: Token has not been explored");
            if (block.timestamp - previousExplorationTimestamp < currentRaffle.ticketInterval) {
                // elapsed time insufficient, contine to the next tokenId
                continue;
            }
            _claimTicket(tokenIds[i]);
            if (currentRaffle.ticketInterval + block.timestamp < currentRaffle.startTime + currentRaffle.duration) {
                explorations[tokenIds[i]][currentRaffleIndex] = block.timestamp;
                emit Explored(tokenIds[i], currentRaffleIndex, block.timestamp);
            } else {
                explorations[tokenIds[i]][currentRaffleIndex] = 0;
            }
        }
    }

    /// @notice conclude current raffle
    /// @dev can only be called after raffle has ended
    function concludeCurrentRaffle() external {
        require(raffles.length > currentRaffleIndex, "NoRaffles: No raffles have been setup");
        Raffle storage currentRaffle = raffles[currentRaffleIndex];
        uint256 endTime = currentRaffle.startTime + currentRaffle.duration;
        require(endTime <= block.timestamp, "RaffleNotEnded: Raffle has not ended");
        require(currentRaffle.vrfRequestId == 0, "VRFAlreadyRequested: VRF has already been requested");

        currentRaffle.vrfRequestId = requestRandomness(vrfCallbackGasLimit, 3, 1);
        currentRaffle.vrfRequestEstimatedExpense = VRF_V2_WRAPPER.calculateRequestPrice(vrfCallbackGasLimit);
    }

    ////////////////////////////
    ////////////////////////////
    ////// VIEW FUNCTIONS //////
    ////////////////////////////
    ////////////////////////////

    /// @notice get current raffle details
    /// @param raffleIndex index of raffle
    /// @return raffle details
    function getRaffle(uint256 raffleIndex) external view returns (Raffle memory) {
        return raffles[raffleIndex];
    }

    /// @notice get an array of ticket numbers that a MyMetaShark NFT token has
    /// @param sharkTokenId token id of MyMetaShark NFT
    /// @param raffleIndex index of raffle
    /// @return array of ticket numbers that a MyMetaShark NFT token has
    function getTickets(uint256 sharkTokenId, uint256 raffleIndex) external view returns (uint256[] memory) {
        return sharkTokenIdToRaffleTicketNumbers[sharkTokenId][raffleIndex];
    }

    /// @notice get an array of ticket numbers that has won the raffle of index raffleIndex
    /// @param raffleIndex index of raffle
    /// @return array of ticket numbers that has won the raffle of index raffleIndex
    function getRaffleWinners(uint256 raffleIndex) external view returns (uint256[] memory) {
        require(raffles.length > raffleIndex, "InvalidRaffleIndex: Raffle does not exist");
        require(raffles[raffleIndex].randomNumber != 0, "RaffleNotConcluded: Raffle has not been concluded");
        Raffle storage raffle = raffles[raffleIndex];
        uint256[] memory winners = new uint256[](raffle.winnerCount);

        uint256 winnerIndex = 0;

        // if winnerCount >= ticketsClaimed, all tickets are winners
        // else, draw winners
        if (raffle.winnerCount >= raffle.ticketsClaimed) {
            for (uint256 i = 0; i < raffle.ticketsClaimed; i++) {
                winners[winnerIndex] = i;
                winnerIndex += 1;
            }
        } else {
            for (uint256 i = 0; i < raffle.winnerCount; i++) {
                uint256 expandedRandomNumber = uint256(keccak256(abi.encode(raffle.randomNumber, i)));
                uint256 winningTicket = getWinningTicket(expandedRandomNumber, raffle.ticketsClaimed, winners, winnerIndex);
                winners[winnerIndex] = winningTicket;
                winnerIndex += 1;
            }
        }
        return winners;
    }

    ////////////////////////////
    ////////////////////////////
    //// INTERNAL FUNCTIONS ////
    ////////////////////////////
    ////////////////////////////

    /// @notice claim ticket for MyMetaShark NFT token
    /// @param sharkTokenId MyMetaShark NFT token id
    function _claimTicket(uint256 sharkTokenId) internal {
        Raffle storage currentRaffle = raffles[currentRaffleIndex];
        uint256 ticketNumber = currentRaffle.ticketsClaimed;
        sharkTokenIdToRaffleTicketNumbers[sharkTokenId][currentRaffleIndex].push(ticketNumber);
        emit TicketClaimed(sharkTokenId, currentRaffleIndex, ticketNumber);
        currentRaffle.ticketsClaimed += 1;
    }

    /// @notice fulfill VRF request, set random number for current raffle, increment currentRaffleIndex
    /// @param _requestId request id
    /// @param _randomWords random words
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(raffles[currentRaffleIndex].vrfRequestEstimatedExpense != 0, "VRFNotRequested: VRF has not been requested");
        require(raffles[currentRaffleIndex].vrfRequestId == _requestId, "VRFRequestIdMisMatch: RequestId does not match raffle requestId");
        require(raffles[currentRaffleIndex].randomNumber == 0, "randomNumber already set");
        raffles[currentRaffleIndex].randomNumber = _randomWords[0];
        emit RaffleConcluded(currentRaffleIndex, _randomWords[0]);
        currentRaffleIndex += 1;
    }

    /// @notice get winning ticket number
    /// @dev terrible time complexity, but it's fine since it's a view function
    /// @dev if winning ticket has already been drawn, increment winning ticket by 1 until a winning ticket is found
    /// @dev logic details in README.md
    /// @param expandedRandomNumber expanded random number
    /// @param ticketsClaimed number of tickets claimed
    /// @param drawnWinners array of drawn winners
    /// @param upperbound upperbound index of drawnWinners array
    /// @return winning ticket number

    function getWinningTicket(uint256 expandedRandomNumber, uint256 ticketsClaimed, uint256[] memory drawnWinners, uint256 upperbound) internal pure returns (uint256) {
        // cannot define a mapping within a function so we use an array to keep track of drawn winners instead of a hash map
        // terrible time complexity, but it's fine since it's a view function
        uint256 winningTicket = expandedRandomNumber % ticketsClaimed;

        for (uint256 i = 0; i < ticketsClaimed; i++) {
            if (drawnWinners.has(winningTicket, upperbound)) {
                winningTicket = (winningTicket + 1) % ticketsClaimed;
            } else {
                break;
            }
        }
        return winningTicket;
    }
}
