// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint() external {
        _mint(msg.sender, 100 ether);
    }
}
