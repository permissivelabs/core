// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "zerodev/validator/IValidator.sol";
import "account-abstraction/interfaces/UserOperation.sol";
import "../../utils/Permission.sol";
import "../../core/PermissionVerifier.sol";

contract PermissiveValidator is IKernelValidator {
    PermissionVerifier immutable permissionVerifier;

    constructor(PermissionVerifier verifier) {
        permissionVerifier = verifier;
    }

    function enable(bytes calldata) external override {}

    function disable(bytes calldata) external pure override {}

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        (bool success, bytes memory returnData) = address(permissionVerifier)
            .delegatecall(
                abi.encodeWithSelector(
                    PermissionVerifier.verify.selector,
                    userOp,
                    userOpHash,
                    missingAccountFunds
                )
            );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        validationData = uint256(bytes32(returnData));
    }

    function validateSignature(
        bytes32 hash,
        bytes calldata signature
    ) external view override returns (uint256) {}
}
