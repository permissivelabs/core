// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";

/**
 * @title IPermissionExecutor - The core contract in change or executing the userOperation after paying the FeeManager and transforming the AllowanceCalldata to ABI
 * @author Flydexo - @Flydex0
 * @notice Emits events for the Indexer
 */
interface IPermissionExecutor {
    /**
     * @notice PermissionUsed - When a permissioned userOperation passed with success
     * @param permHash The hash of the permission
     * @param dest The called contract
     * @param value The msg.value
     * @param func The AllowanceCalldata used to call the contract
     * @param permission The permission object
     * @param gasFee The fee for the userOperation (used to compute the Permissive fee)
     */
    event PermissionUsed(
        bytes32 indexed permHash, address dest, uint256 value, bytes func, Permission permission, uint256 gasFee
    );

    /**
     * @notice Execute a permissioned userOperation
     * @param dest The called contract
     * @param value The msg.value
     * @param func The AllowanceCalldata used to call the contract
     * @param permission The permission object
     * @param gasFee The fee for the userOperation (used to compute the Permissive fee)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission,
        bytes32[] calldata proof,
        uint256 gasFee
    ) external;
}
