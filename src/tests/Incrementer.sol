// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

contract Incrementer {
    uint public value = 0;

    function increment() external {
        value = value + 1;
    }
}
