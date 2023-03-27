// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/samples/TokenPaymaster.sol";

contract PermissivePaymaster is TokenPaymaster {
    constructor(
        address accountFactory,
        string memory _symbol,
        IEntryPoint _entryPoint
    ) TokenPaymaster(accountFactory, _symbol, _entryPoint) {}
}
