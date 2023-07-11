// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";

interface IPermissionExecutor {
    event PermissionUsed(
        bytes32 indexed permHash, address dest, uint256 value, bytes func, Permission permission, uint256 gasFee
    );
}
