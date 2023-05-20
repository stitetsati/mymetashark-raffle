# Requirements

### Smart Contract:

All costs associated with deploying smart contracts to the Ethereum blockchain shall be paid for by the project owner.

1. Admin functions

    a. ```SetupRaffle(startTime, duration, ticketInterval, winnerCount)``` :white_check_mark:
    - Allows the admin to set up the next raffle details, including start time, duration, ticket interval, winner count
2. User Functions 

    a. ```Explore(tokenIds[])``` :white_check_mark:

    - Allows the mymetashark holders to join the current raffle ticket-collection process(Explore & Claim). 
    
    - This function requires the front end to send an array of my metashark tokenIds; i.e. if the user selects the button "explore all", the front end should give the smart contract all the mymetashark tokenIds that this user holds. 
    - An exception is that when the user holds more than 100 mymetashark NFTs,
        due to the block limit of the Ethereum blockchain, the front end needs to lead the user to execute multiple transactions with different batches of tokenIds in order to "explore all"
    - <strong>Error Conditions</strong>:
        1. There is no currently active raffle: the admin has not setup the next raffle, see function 1.a
        
        2. By the time the user hits 'explore', the duration of time between the action and the end of the raffle is less than the ticket interval; i.e. raffle ends at 1pm; ticket interval is 30 minutes; the user hits 'explore' at 12:31pm. 

    b. ```Claim(tokenIds[])``` :white_check_mark:

    - Allows the mymetashark holders who has 'explored' and 'ticket interval' has passed. 
    - The tokenIds that have satisfied the aforementioned criteria will have one ticket attached to them, making them eligible for the lottery reward by the end of the raffle.
    - Allows the tokenIds to auto "explore" after claiming, if no error condition in 2.a. satisfies.

    c. ```ConcludeCurrentRaffle()```

    - Allows anyone to conclude a raffle round that has come to an end (current time >= raffle.startTime+duration)
    - Triggers a Chainlink's VRF for a random number (The developers are not responsible for refilling the $LINK tokens or any costs required to interact with Chainlink's VRF)
    - Winners are drawn.

### Subgraph

#### 1. Raffle Data

- allows the API consumer to get each raffle round's data, including:

    a. winning tokenIds & the holder addresses 

    b. number of tokenIds participated in each raffle

    c. number of tickets issued in each raffle

    d. number of distinct wallet addresses participated in each raffle (recorded at the time of contract interaction, subsequent effects of NFT transfers won't be included.)

#### 2. Mymetashark TokenId Data  
- allows the API consumer to get each mymetashark tokenId's records of interaction with the raffle smart contract, including: 

    a. raffles in which this tokenId has participated

    b. for each round of raffle this tokenId has particiapted in, the ticket numbers associated with this tokenId and ticket numbers (if any) that won the rewards
    
        
        
# Documentation

## Randomness

This section explains how winners are drawn given a random number provided by Chainlink's VRF.

Assuming that the number of winners that is to be drawn for the current round of raffle is 20, and the total number of tickets are 120 (i.e. ticket number 0 - 119), we will expand the VRF's random value by keccak256 hashing the abi.encode(randomValue, i) where i is 0...19 and then modulo the result with 120, this will create 20 random numbers in the range of 0...119.

If the same number is drawn as a winning number, we will use [linear probing](https://en.wikipedia.org/wiki/Linear_probing) to solve the collision.

In addition, the for-loop that executes the randomness drawing operation is not implemented in the fulfillRandomness function; the function simply stores the VRF result so that the tx does not consume a tremendous amount of gas when the number of winners that is to be drawn is forbiddingly large. 

Instead, a view function is implemented in the smart contract for the front end to query whether a given number has won in a particular round of raffle, making it verifiably transparent to all. The same mechanism is also implemented in the subgraph for querying all winning numbers for a given round of raffles.
