// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

/**
 * @title Permission
 * @author Flydexo - @Flydex0
 * @notice A permission is made for a specific function of a specific contract
 * @dev 1 operator = 1 permission set
 * @dev 1 permission set = infinite permissions
 */
struct Permission {
    // The address authorized to use this permission to make an userOperation on behalf of the account
    address operator;
    // The address that this permission permits to call
    address to;
    // The function that this permission permits to call on the to contract
    bytes4 selector;
    // see {AllowanceCalldata}
    bytes allowed_arguments;
    // If set, the userOperation won't pass unless the paymaster is equal to the permission's paymaster
    address paymaster;
    // The UNIX timestamp (seconds) when the permission is not valid anymore (0 = infinite)
    uint48 validUntil;
    // The UNIX timestamp when the permission becomes valid
    uint48 validAfter;
    // The maximum number of times + 1 this permission can be used (0 = infinite, 1 = 0, n = n - 1)
    uint256 maxUsage;
    // The address called to make additional checks on the userOperation, see {IDataValidator}
    address dataValidator;
}

/**
 * @title PermissionLib
 * @author Flydexo - @Flydex0
 * @notice Library used to hash the Permission struct
 */
library PermissionLib {
    function hash(Permission memory permission) internal pure returns (bytes32 permHash) {
        permHash = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
                permission.allowed_arguments,
                permission.paymaster,
                permission.validUntil,
                permission.validAfter,
                permission.maxUsage,
                permission.dataValidator
            )
        );
    }
}
