// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../../src/utils/Permission.sol";

library DomainSeparatorUtils {
    function buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash,
        address target
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    block.chainid,
                    target
                )
            );
    }

    function efficientHash(
        bytes32 a,
        bytes32 b
    ) public pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

contract SigUtils {
    bytes32 public DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    bytes32 public constant TYPEHASH =
        0xd7e1e23484f808c5620ce8d904e88d7540a3eeb37ac94e636726ed53571e4e3c;

    function getStructHash(
        PermissionSet memory _permit
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _permit.operator,
                    _permit.merkleRootPermissions
                )
            );
    }

    function getTypedDataHash(
        PermissionSet memory _permit
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(_permit)
                )
            );
    }
}
