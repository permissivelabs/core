// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "account-abstraction/interfaces/UserOperation.sol";
import "../../utils/Permission.sol";

interface ISafeModule {
    event OperatorMutated(
        address indexed operator,
        bytes32 indexed oldPermissions,
        bytes32 indexed newPermissions
    );
    event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);
    event PermissionUsed(
        bytes32 indexed permHash,
        address dest,
        uint256 value,
        bytes func,
        Permission permission,
        uint256 gasFee
    );
    event NewSafe(address safe);
}
