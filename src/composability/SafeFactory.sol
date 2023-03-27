// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Safe.sol";

contract SafeFactory {
    PermissiveSafe public immutable accountImplementation;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new PermissiveSafe(address(_entryPoint));
    }

    function createAccount(
        address owner,
        uint256 salt
    ) public returns (PermissiveSafe ret) {
        address addr = getAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return PermissiveSafe(payable(addr));
        }
        ret = PermissiveSafe(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(PermissiveSafe.initialize, (owner))
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
                            abi.encodeCall(PermissiveSafe.initialize, (owner))
                        )
                    )
                )
            );
    }
}
