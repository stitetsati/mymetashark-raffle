// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "openzeppelin-contracts/contracts/access/Ownable.sol";

// import "forge-std/console.sol";

interface IMyMetaSharkRaffle {
    function setupRaffle(uint256 startTime, uint256 duration, uint256 ticketInterval, uint256 winnerCount) external;
    // function explore(uint256[] calldata tokenIds) external;
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
    Raffle[] public raffles;

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

    function getRaffle(uint256 raffleIndex) public view returns (Raffle memory) {
        return raffles[raffleIndex];
    }
}
