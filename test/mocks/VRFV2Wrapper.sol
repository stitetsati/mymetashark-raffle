pragma solidity ^0.8.4;

interface Target {
    function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external;
}

contract VRFV2Wrapper {
    function calculateRequestPrice(uint32 _callbackGasLimit) external pure returns (uint256) {
        _callbackGasLimit;
        return 0.1 ether;
    }

    function lastRequestId() external view returns (uint256) {
        return uint256(keccak256(abi.encode(block.timestamp)));
    }

    function fulfillRandomness(uint256 requestId, address target) external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encode(block.timestamp)));
        Target(target).rawFulfillRandomWords(requestId, randomWords);
    }
}
