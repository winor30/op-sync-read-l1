pragma solidity ^0.8.25;

contract L1Counter {
    uint256 public count = 123;

    function inc() external {
        ++count;
    }
}
