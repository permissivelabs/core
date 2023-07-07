// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/IPermissionRegistry.sol";

// keccak256("PermissionSet(address operator,bytes32 merkleRootPermissions)")
bytes32 constant typedStruct = 0xd7e1e23484f808c5620ce8d904e88d7540a3eeb37ac94e636726ed53571e4e3c;

contract PermissionRegistry is EIP712, IPermissionRegistry {
    mapping(address sender => mapping(address operator => bytes32 permHash))
        public operatorPermissions;

    mapping(address sender => mapping(bytes32 permHash => uint256 remainingUsage))
        public remainingPermUsage;

    constructor() EIP712("Permisive PermissionRegistry", "0.0.46") {}

    function setRemainingPermUsage(
        bytes32 permHash,
        uint256 remainingUsage
    ) external {
        remainingPermUsage[msg.sender][permHash] = remainingUsage;
    }

    function setOperatorPermissions(
        PermissionSet calldata permSet,
        bytes calldata signature
    ) external {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    typedStruct,
                    permSet.operator,
                    permSet.merkleRootPermissions
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        bytes32 oldValue = operatorPermissions[signer][permSet.operator];
        operatorPermissions[signer][permSet.operator] = permSet
            .merkleRootPermissions;
        emit OperatorMutated(
            permSet.operator,
            oldValue,
            permSet.merkleRootPermissions
        );
    }
}
