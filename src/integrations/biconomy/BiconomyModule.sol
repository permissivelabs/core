// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "biconomy/modules/BaseAuthorizationModule.sol";
import "biconomy/base/ModuleManager.sol";
import "../../core/PermissionVerifier.sol";
import "../../core/PermissionExecutor.sol";

contract BiconomyAuthorizationModule is BaseAuthorizationModule {
    PermissionVerifier immutable permissionVerifier;
    PermissionExecutor immutable permissionExecutor;

    constructor(PermissionVerifier _verifier, PermissionExecutor _executor) {
        permissionVerifier = _verifier;
        permissionExecutor = _executor;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256 validationData) {
        (bool success, bytes memory returnData) = address(permissionVerifier)
            .delegatecall(
                abi.encodeWithSelector(
                    PermissionVerifier.verify.selector,
                    userOp,
                    userOpHash,
                    0
                )
            );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        validationData = uint256(bytes32(returnData));
    }

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        Permission calldata permission,
        bytes32[] calldata,
        uint256 gasFee
    ) external {
        (bool success, bytes memory returnData) = ModuleManager(msg.sender)
            .execTransactionFromModuleReturnData(
                address(permissionExecutor),
                0,
                abi.encodeWithSelector(
                    PermissionExecutor.execute.selector,
                    dest,
                    value,
                    func,
                    permission,
                    gasFee
                ),
                Enum.Operation.DelegateCall
            );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signature
    ) public view override returns (bytes4) {}
}
