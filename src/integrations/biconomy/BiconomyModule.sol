// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "biconomy/modules/BaseAuthorizationModule.sol";
import "biconomy/base/ModuleManager.sol";
import "../../core/PermissionVerifier.sol";
import "../../core/PermissionExecutor.sol";
import "bytes/BytesLib.sol";

contract BiconomyAuthorizationModule is BaseAuthorizationModule {
    using BytesLib for bytes;

    PermissionVerifier immutable permissionVerifier;
    PermissionExecutor immutable permissionExecutor;

    constructor(PermissionVerifier _verifier, PermissionExecutor _executor) {
        permissionVerifier = _verifier;
        permissionExecutor = _executor;
    }

    function validateUserOp(UserOperation memory userOp, bytes32 userOpHash)
        external
        returns (uint256 validationData)
    {
        (bytes memory sig,) = abi.decode(userOp.signature, (bytes, address));
        userOp.signature = sig;
        (,, bytes memory callData) =
            abi.decode(userOp.callData.slice(4, userOp.callData.length - 4), (address, uint256, bytes));
        userOp.callData = callData;
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

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        Permission calldata permission,
        bytes32[] calldata proof,
        uint256 gasFee
    ) external {
        (bool success, bytes memory returnData) = ModuleManager(msg.sender).execTransactionFromModuleReturnData(
            address(permissionExecutor),
            0,
            abi.encodeWithSelector(PermissionExecutor.execute.selector, dest, value, func, permission, proof, gasFee),
            Enum.Operation.DelegateCall
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    function isValidSignature(bytes32 _dataHash, bytes memory _signature) public view override returns (bytes4) {}
}
