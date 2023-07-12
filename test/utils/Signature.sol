// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../../src/utils/Permission.sol";

library DomainSeparatorUtils {
    function buildDomainSeparator(bytes32 typeHash, bytes32 nameHash, bytes32 versionHash, address target)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, target));
    }

    function efficientHash(bytes32 a, bytes32 b) public pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
