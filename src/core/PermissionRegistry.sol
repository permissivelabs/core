// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";
import "../interfaces/IPermissionRegistry.sol";

/**
 * @dev see {IPermissionRegistry}
 */
contract PermissionRegistry is IPermissionRegistry {
    mapping(address sender => mapping(address operator => bytes32 permHash)) public operatorPermissions;

    mapping(address sender => mapping(bytes32 permHash => uint256 remainingUsage)) public remainingPermUsage;

    constructor() {}

    function setRemainingPermUsage(bytes32 permHash, uint256 remainingUsage) external {
        remainingPermUsage[msg.sender][permHash] = remainingUsage;
    }

    function setOperatorPermissions(address operator, bytes32 root) external {
        bytes32 oldValue = operatorPermissions[msg.sender][operator];
        operatorPermissions[msg.sender][operator] = root;
        emit OperatorMutated(operator, oldValue, root);
    }
}
