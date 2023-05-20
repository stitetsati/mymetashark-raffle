// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// import "forge-std/console.sol";

interface IMyMetaSharkRaffle {
    function setupRaffle(uint256 startTime, uint256 duration, uint256 ticketInterval, uint256 winnerCount) external;

    function explore(uint256[] calldata tokenIds) external;
    // function claim(uint256[] calldata tokenIds) external;
    // function concludeCurrentRaffle() external;
}

contract MyMetaSharkRaffle is IMyMetaSharkRaffle, Ownable {
    struct Raffle {
        uint256 startTime;
        uint256 duration;
        uint256 ticketInterval;
        uint256 winnerCount;
        uint256 ticketsClaimed;
        uint256 randomNumber;
    }
    uint256 public currentRaffleIndex = 0;
    address public myMetaShark;
    // mymetashark => raffleIndex => explorationTimestamp
    mapping(uint256 => mapping(uint256 => uint256)) public explorations;
    // mymetashark => raffleIndex => ticketNumbers
    mapping(uint256 => mapping(uint256 => uint256[])) public sharkTokenIdToRaffleTicketNumbers;

    Raffle[] public raffles;

    constructor(address _myMetaShark) {
        myMetaShark = _myMetaShark;
    }

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
        raffles.push(Raffle(startTime, duration, ticketInterval, winnerCount, 0, 0));
    }

    function getRaffle(uint256 raffleIndex) external view returns (Raffle memory) {
        return raffles[raffleIndex];
    }

    function getTickets(uint256 sharkTokenId, uint256 raffleIndex) external view returns (uint256[] memory) {
        return sharkTokenIdToRaffleTicketNumbers[sharkTokenId][raffleIndex];
    }

    function explore(uint256[] calldata tokenIds) external {
        require(raffles.length > 0, "NoRaffles: No raffles have been setup");
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
                    claimTicket(tokenIds[i]);
                } else {
                    revert("AlreadyExplored: Token already explored and time elapsed has not reached ticket interval");
                }
            }
            // set exploration timestamp
            explorations[tokenIds[i]][currentRaffleIndex] = block.timestamp;
        }
    }

    function claimTicket(uint256 tokenId) internal {
        Raffle storage currentRaffle = raffles[currentRaffleIndex];
        sharkTokenIdToRaffleTicketNumbers[tokenId][currentRaffleIndex].push(currentRaffle.ticketsClaimed);
        currentRaffle.ticketsClaimed += 1;
    }
}
