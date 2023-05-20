pragma solidity ^0.8.4;
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("TEST", "TEST") {
        _mint(msg.sender, 100_000_000 ether);
    }

    function transferAndCall(address _to, uint _value, bytes calldata _data) public returns (bool success) {
        return true;
    }
}
