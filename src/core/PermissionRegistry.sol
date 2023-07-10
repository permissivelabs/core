// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";
import "../interfaces/IPermissionRegistry.sol";

contract PermissionRegistry is IPermissionRegistry {
    mapping(address sender => mapping(address operator => bytes32 permHash))
        public operatorPermissions;

    mapping(address sender => mapping(bytes32 permHash => uint256 remainingUsage))
        public remainingPermUsage;

    constructor() {}

    function setRemainingPermUsage(
        bytes32 permHash,
        uint256 remainingUsage
    ) external {
        remainingPermUsage[msg.sender][permHash] = remainingUsage;
    }

    function setOperatorPermissions(PermissionSet calldata permSet) external {
        bytes32 oldValue = operatorPermissions[msg.sender][permSet.operator];
        operatorPermissions[msg.sender][permSet.operator] = permSet
            .merkleRootPermissions;
        emit OperatorMutated(
            permSet.operator,
            oldValue,
            permSet.merkleRootPermissions
        );
    }
}
