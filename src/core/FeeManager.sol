// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
    uint24 public fee = 2000;
    bool initialized;

    event FeePaid(address indexed from, uint256 amount);

    function initialize(address owner) external {
        require(!initialized);
        _transferOwnership(owner);
        initialized = true;
    }

    function setFee(uint24 _fee) external {
        _checkOwner();
        fee = _fee;
    }

    receive() external payable {
        payable(owner()).transfer(address(this).balance);
        emit FeePaid(msg.sender, msg.value);
    }
}
