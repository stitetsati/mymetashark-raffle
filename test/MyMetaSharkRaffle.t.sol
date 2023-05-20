// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./mocks/NFT.sol";
import "../src/MyMetaSharkRaffle.sol";

contract MyMetaSharkRaffleTest is Test {
    MyMetaSharkRaffle raffleContract;
    NFT shark;
    address owner = 0x0000000000000000000000000000000000000001;

    constructor() {
        vm.startPrank(owner);
        shark = new NFT();
        raffleContract = new MyMetaSharkRaffle(address(shark));
        vm.stopPrank();
    }

    function testSetupRaffleAccessControl() external {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        raffleContract.setupRaffle(0, 0, 0, 0);
    }

    function testSetupRaffle() external {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        MyMetaSharkRaffle.Raffle memory r = raffleContract.getRaffle(0);
        assertEq(r.startTime, startTime);
        assertEq(r.duration, duration);
        assertEq(r.ticketInterval, ticketInterval);
        assertEq(r.winnerCount, winnerCount);
        assertEq(r.ticketsClaimed, 0);
        assertEq(r.randomNumber, 0);
    }

    function testSetupRaffleWithInvalidParams() external {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp - 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        vm.expectRevert(bytes("InvalidStartTime: Must be in the future"));
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 1 days;
        ticketInterval = 0;
        winnerCount = 10;
        startTime = block.timestamp + 1;
        vm.expectRevert(bytes("InvalidTicketInterval: Must be greater than 0"));
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 1 days;
        ticketInterval = 1 days;
        winnerCount = 10;
        vm.expectRevert(bytes("InvalidTicketInterval: Must be less than or equal to duration"));
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 0;
        ticketInterval = 30 minutes;
        winnerCount = 10;
        vm.expectRevert(bytes("InvalidDuration: Must be greater than 0"));
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 1 days;
        ticketInterval = 30 minutes;
        winnerCount = 0;
        vm.expectRevert(bytes("InvalidWinnerCount: Must be greater than 0"));
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);
    }

    function testSetupRaffleWithStartTimeEarlierThanPreviousEndTime() external {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        startTime = startTime + duration - 1;
        vm.expectRevert(bytes("InvalidStartTime: Must be after previous raffle end"));
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        startTime = startTime + duration + 1;
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);
    }

    function setupRaffle() internal returns (MyMetaSharkRaffle.Raffle memory) {
        uint256 startTime = block.timestamp + 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        vm.prank(owner);
        raffleContract.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        return raffleContract.getRaffle(0);
    }

    function testExploreWithoutRaffle() external {
        vm.expectRevert(bytes("NoRaffles: No raffles have been setup"));
        uint256[] memory tokenIds = new uint256[](0);
        raffleContract.explore(tokenIds);
    }

    function testExploreWithRaffle() external {
        // setup raffle
        MyMetaSharkRaffle.Raffle memory raffle = setupRaffle();
        vm.warp(raffle.startTime);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        vm.prank(owner);
        raffleContract.explore(tokenIds);
    }

    function testExploreRaffleReverts() external {
        // setup raffle
        MyMetaSharkRaffle.Raffle memory raffle = setupRaffle();
        uint256[] memory tokenIds = new uint256[](1);
        uint256 tokenId = 0;
        tokenIds[0] = tokenId;
        vm.expectRevert(bytes("RaffleNotStarted: Raffle has not started"));
        raffleContract.explore(tokenIds);

        // warp to start time
        vm.warp(raffle.startTime);
        // give empty array
        vm.expectRevert(bytes("InvalidTokenIds: Must have at least one token id"));
        raffleContract.explore(new uint256[](0));

        // warp to end time
        vm.warp(raffle.startTime + raffle.duration + 1);
        vm.expectRevert(bytes("RaffleEnded: Raffle has ended"));
        raffleContract.explore(tokenIds);

        // warp to end time - interval + 1
        vm.warp(raffle.startTime + raffle.duration - 1);
        vm.expectRevert(bytes("InvalidExplorationTime: Remaining time is less than ticket interval"));
        raffleContract.explore(tokenIds);

        vm.warp(raffle.startTime);
        // nft is held by owner. without prank, it should revert
        vm.expectRevert(bytes("InvalidTokenOwner: Must own token"));
        raffleContract.explore(tokenIds);

        // prank owner, should explore successfully
        vm.prank(owner);
        raffleContract.explore(tokenIds);
        uint256 explorationTimestamp = raffleContract.explorations(tokenId, raffleContract.currentRaffleIndex());
        assertEq(explorationTimestamp, raffle.startTime);
    }

    function testExploreWhenAlreadyExploring() public {
        MyMetaSharkRaffle.Raffle memory raffle = setupRaffle();
        uint256[] memory tokenIds = new uint256[](1);
        uint256 tokenId = 0;
        tokenIds[0] = tokenId;

        // warp to start time
        vm.warp(raffle.startTime);
        vm.startPrank(owner);
        raffleContract.explore(tokenIds);
        uint256[] memory tickets = raffleContract.getTickets(tokenId, raffleContract.currentRaffleIndex());
        // no tickets claimed when first explored
        assertEq(tickets.length, 0);

        // explore again
        vm.expectRevert(bytes("AlreadyExplored: Token already explored and time elapsed has not reached ticket interval"));
        raffleContract.explore(tokenIds);

        // warp to start time + ticket interval

        vm.warp(raffle.startTime + raffle.ticketInterval);
        raffleContract.explore(tokenIds);

        // verify effects
        uint256 explorationTimestamp = raffleContract.explorations(tokenId, raffleContract.currentRaffleIndex());
        // updated exploration time stamp
        assertEq(explorationTimestamp, raffle.startTime + raffle.ticketInterval);
        tickets = raffleContract.getTickets(tokenId, raffleContract.currentRaffleIndex());

        // tickets claimed
        assertEq(tickets.length, 1);
        assertEq(tickets[0], 0);
        // raffle ticket count updated
        assertEq(raffleContract.getRaffle(raffleContract.currentRaffleIndex()).ticketsClaimed, 1);
    }
}
