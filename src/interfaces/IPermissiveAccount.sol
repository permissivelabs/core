// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "account-abstraction/interfaces/IAccount.sol";
import "./Permission.sol";

struct PermissionSet {
    address operator;
    bytes32 merkleRootPermissions;
}

interface IPermissiveAccount is IAccount {
    error InvalidProof();
    error NotAllowed(address);
    error InvalidTo(address provided, address expected);
    error ExceededValue(uint256 value, uint256 max);
    error OutOfPerms(bytes32 perm);
    error ExceededFees(uint256 fee, uint256 maxFee);
    error InvalidPermission();
    error InvalidPaymaster(address provided, address expected);
    error InvalidSelector(bytes4 provided, bytes4 expected);
    error ExpiredPermission(uint256 current, uint256 expiredAt);

    event OperatorMutated(address indexed operator, bytes32 indexed oldPermissions, bytes32 indexed newPermissions);
    event UserOpValidated(bytes32 indexed userOpHash, UserOperation userOp);
    event PermissionUsed(
        bytes32 indexed permHash,
        address dest,
        uint256 value,
        bytes func,
        PermissionLib.Permission permission,
        uint256 gasFee
    );

    function initialize(address owner) external;

    function setOperatorPermissions(PermissionSet calldata permSet, bytes calldata signature) external;
}
