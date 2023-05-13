// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
    uint256 public fee = 2000;
    bool initialized;
    event FeePaid(address indexed from, uint amount);

    function initialize(address owner) external {
        require(!initialized);
        _transferOwnership(owner);
        initialized = true;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {
        emit FeePaid(msg.sender, msg.value);
    }
}
