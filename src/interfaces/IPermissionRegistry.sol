// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";

interface IPermissionRegistry {
    event OperatorMutated(
        address indexed operator,
        bytes32 indexed oldPermissions,
        bytes32 indexed newPermissions
    );

    function operatorPermissions(
        address sender,
        address operator
    ) external view returns (bytes32 permHash);

    function remainingPermUsage(
        address sender,
        bytes32 permHash
    ) external view returns (uint256 remainingUsage);

    function setRemainingPermUsage(
        bytes32 permHash,
        uint256 remainingUsage
    ) external;

    function setOperatorPermissions(
        PermissionSet calldata permSet,
        bytes calldata signature
    ) external;
}
