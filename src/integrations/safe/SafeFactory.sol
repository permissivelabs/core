// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./SafeModule.sol";

contract SafeFactory {
    SafeModule public immutable moduleImplementation;

    event AccountCreated(address indexed safe, uint256 indexed salt, address indexed account);

    constructor(address entrypoint, address payable feeManager) {
        moduleImplementation = new SafeModule(entrypoint, feeManager);
    }

    function createAccount(address safe, uint256 salt) public returns (SafeModule ret) {
        address addr = getAddress(safe, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SafeModule(payable(addr));
        }
        ret = SafeModule(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(moduleImplementation),
                    abi.encodeCall(SafeModule.setSafe, (safe))
                )
            )
        );
        emit AccountCreated(safe, salt, address(ret));
    }

    function getAddress(address safe, uint256 salt) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(address(moduleImplementation), abi.encodeCall(SafeModule.setSafe, (safe)))
                )
            )
        );
    }
}
