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

    function withdraw() external {
        _checkOwner();
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {
        emit FeePaid(msg.sender, msg.value);
    }
}
