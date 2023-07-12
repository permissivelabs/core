// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/Permission.sol";

/**
 * @title IPermissionRegistry - The contract in charge of storing all Permissive related storage.
 * @author Flydexo - @Flydex0
 * @notice PermissionRegistry stores the permissions of an operator on an account and the remaining usages of a permission on an account.
 */
interface IPermissionRegistry {
    /**
     * @notice OperatorMutated - Emitted when the granted permisssions for an operator on an account change
     * @param operator The address of the operator
     * @param oldPermissions The old permission set hash
     * @param newPermissions The new permission set hash
     */
    event OperatorMutated(address indexed operator, bytes32 indexed oldPermissions, bytes32 indexed newPermissions);

    /**
     * @notice operatorPermissions - Getter for the granted permissions of an operator on an account
     * @param sender The account address
     * @param operator The operator address
     */
    function operatorPermissions(address sender, address operator) external view returns (bytes32 permHash);

    /**
     * @notice remainingPermUsage - Getter for the remaining usage of a permission on an account (usage + 1)
     * @param sender The account address
     * @param permHash The permission hash
     */
    function remainingPermUsage(address sender, bytes32 permHash) external view returns (uint256 remainingUsage);

    /**
     * @notice setOperatorPermissions - Setter for the granted permissions of an operator on an account. Can only be called by the account modifying it's own operator permissions.
     * @param operator The operator address
     * @param root The permissions merkle root
     */
    function setOperatorPermissions(address operator, bytes32 root) external;

    /**
     * @notice setRemainingPermUsage - Setter for the remaining usage of a permission on an account. Can only be called by the account modifying it's own usage
     * @param permHash The permission hash
     * @param remainingUsage The permission remaining usage (usage + 1)
     */
    function setRemainingPermUsage(bytes32 permHash, uint256 remainingUsage) external;
}
