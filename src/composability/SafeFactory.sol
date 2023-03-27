// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Safe.sol";
import "hardhat/console.sol";

contract SafeFactory {
    PermissiveGnosis public immutable accountImplementation;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new PermissiveGnosis(address(_entryPoint));
    }

    function createAccount(
        address owner,
        uint256 salt
    ) public returns (PermissiveGnosis ret) {
        address addr = getAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return PermissiveGnosis(payable(addr));
        }
        ret = PermissiveGnosis(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(PermissiveGnosis.initialize, (owner))
                )
            )
        );
    }

    function getAddress(
        address owner,
        uint256 salt
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplementation),
                            abi.encodeCall(PermissiveGnosis.initialize, (owner))
                        )
                    )
                )
            );
    }
}
