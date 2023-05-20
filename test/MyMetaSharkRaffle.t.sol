// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./mocks/NFT.sol";
import "../src/MyMetaSharkRaffle.sol";

contract MyMetaSharkRaffleTest is Test {
    MyMetaSharkRaffle raffle;
    address owner = 0x0000000000000000000000000000000000000001;

    constructor() {
        vm.startPrank(owner);
        raffle = new MyMetaSharkRaffle();
        vm.stopPrank();
    }

    function testSetupRaffleAccessControl() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        raffle.setupRaffle(0, 0, 0, 0);
    }

    function testSetupRaffle() public {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        MyMetaSharkRaffle.Raffle memory r = raffle.getRaffle(0);
        assertEq(r.startTime, startTime);
        assertEq(r.duration, duration);
        assertEq(r.ticketInterval, ticketInterval);
        assertEq(r.winnerCount, winnerCount);
        assertEq(r.ticketsClaimed, 0);
        assertEq(r.randomNumber, 0);
    }

    function testSetupRaffleWithInvalidParams() public {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp - 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        vm.expectRevert(bytes("InvalidStartTime: Must be in the future"));
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 1 days;
        ticketInterval = 0;
        winnerCount = 10;
        startTime = block.timestamp + 1;
        vm.expectRevert(bytes("InvalidTicketInterval: Must be greater than 0"));
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 1 days;
        ticketInterval = 1 days;
        winnerCount = 10;
        vm.expectRevert(bytes("InvalidTicketInterval: Must be less than or equal to duration"));
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 0;
        ticketInterval = 30 minutes;
        winnerCount = 10;
        vm.expectRevert(bytes("InvalidDuration: Must be greater than 0"));
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);

        startTime = block.timestamp + 1;
        duration = 1 days;
        ticketInterval = 30 minutes;
        winnerCount = 0;
        vm.expectRevert(bytes("InvalidWinnerCount: Must be greater than 0"));
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);
    }

    function testSetupRaffleWithStartTimeEarlierThanPreviousEndTime() public {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1;
        uint256 duration = 1 days;
        uint256 ticketInterval = 30 minutes;
        uint256 winnerCount = 10;
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        startTime = startTime + duration - 1;
        vm.expectRevert(bytes("InvalidStartTime: Must be after previous raffle end"));
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);
        startTime = startTime + duration + 1;
        raffle.setupRaffle(startTime, duration, ticketInterval, winnerCount);
    }
}
