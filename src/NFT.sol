//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721 {
    uint256 index = 0;

    constructor() ERC721("TEST", "TEST") {
        for (uint256 i = 0; i < 10; i++) {
            _mint(msg.sender, index);
            index += 1;
        }
    }

    function mint() public {
        _mint(msg.sender, index);
        index += 1;
    }
}
