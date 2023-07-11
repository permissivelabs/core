// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../../core/PermissionVerifier.sol";

contract OperationValidator {
    PermissionVerifier immutable permissionVerifier;

    constructor(PermissionVerifier _verifier) {
        permissionVerifier = _verifier;
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256 validationData)
    {
        (bool success, bytes memory returnData) = address(permissionVerifier).delegatecall(
            abi.encodeWithSelector(PermissionVerifier.verify.selector, userOp, userOpHash, 0)
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        validationData = uint256(bytes32(returnData));
    }
}
