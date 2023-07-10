// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// 4337
import "account-abstraction/core/Helpers.sol";
// interfaces
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../interfaces/IDataValidator.sol";
import "../interfaces/IPermissionVerifier.sol";
// core contracts
import "./PermissionRegistry.sol";
// core libraries
import "../utils/AllowanceCalldata.sol";
import "../utils/Permission.sol";
// utils
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "bytes/BytesLib.sol";

uint256 constant SIG_VALIDATION_FAILED = 1;

contract PermissionVerifier is IPermissionVerifier {
    using ECDSA for bytes32;
    using PermissionLib for Permission;
    using BytesLib for bytes;

    PermissionRegistry immutable permissionRegistry;

    constructor(PermissionRegistry registry) {
        permissionRegistry = registry;
    }

    function verify(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        (
            ,
            ,
            ,
            Permission memory permission,
            bytes32[] memory proof,
            uint256 providedFee
        ) = abi.decode(
                userOp.callData[4:],
                (address, uint256, bytes, Permission, bytes32[], uint256)
            );
        if (permission.operator.code.length > 0) {
            try
                IERC1271(permission.operator).isValidSignature(
                    hash,
                    userOp.signature
                )
            returns (bytes4 magicValue) {
                validationData = _packValidationData(
                    ValidationData({
                        aggregator: magicValue ==
                            IERC1271.isValidSignature.selector
                            ? address(0)
                            : address(1),
                        validAfter: permission.validAfter,
                        validUntil: permission.validUntil
                    })
                );
            } catch {
                validationData = _packValidationData(
                    ValidationData({
                        aggregator: address(1),
                        validAfter: permission.validAfter,
                        validUntil: permission.validUntil
                    })
                );
            }
        } else if (permission.operator != hash.recover(userOp.signature)) {
            return SIG_VALIDATION_FAILED;
        } else {
            validationData = _packValidationData(
                ValidationData({
                    aggregator: address(0),
                    validAfter: permission.validAfter,
                    validUntil: permission.validUntil
                })
            );
        }
        bytes32 permHash = permission.hash();
        _validateMerklePermission(permission, proof, permHash);
        _validatePermission(userOp, permission, permHash);
        _validateData(userOp, userOpHash, missingAccountFunds, permission);
        uint256 gasFee = computeGasFee(userOp);
        if (providedFee != gasFee) revert("Invalid provided fee");
        emit PermissionVerified(userOpHash, userOp);
    }

    function computeGasFee(
        UserOperation memory userOp
    ) public pure returns (uint256 fee) {
        uint256 mul = address(bytes20(userOp.paymasterAndData)) != address(0)
            ? 3
            : 1;
        uint256 requiredGas = userOp.callGasLimit +
            userOp.verificationGasLimit *
            mul +
            userOp.preVerificationGas;

        fee = requiredGas * userOp.maxFeePerGas;
    }

    function _validateData(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        Permission memory permission
    ) internal {
        if (
            permission.dataValidator != address(0) &&
            !IDataValidator(permission.dataValidator).isValidData(
                userOp,
                userOpHash,
                missingAccountFunds
            )
        ) {
            revert("Invalid data");
        }
    }

    function _validatePermission(
        UserOperation calldata userOp,
        Permission memory permission,
        bytes32 permHash
    ) internal {
        (address to, uint256 value, bytes memory callData, , ) = abi.decode(
            userOp.callData[4:],
            (address, uint256, bytes, Permission, bytes32[])
        );
        if (permission.to != to) revert("InvalidTo");
        uint256 rPermU = permissionRegistry.remainingPermUsage(
            address(this),
            permHash
        );
        if (permission.maxUsage > 0) {
            if (permission.maxUsage == 1) revert("OutOfPerms");
            if (rPermU == 1) {
                revert("OutOfPerms2");
            }
            if (rPermU == 0) {
                rPermU = permission.maxUsage;
            }
            rPermU--;
            permissionRegistry.setRemainingPermUsage(permHash, rPermU);
        }
        if (
            !AllowanceCalldata.isAllowedCalldata(
                permission.allowed_arguments,
                callData.slice(4, callData.length - 4),
                value
            )
        ) revert("Not allowed Calldata");
        if (permission.selector != bytes4(callData)) revert("InvalidSelector");
        if (permission.paymaster != address(0)) {
            address paymaster = address(0);
            assembly {
                let paymasterOffset := calldataload(add(userOp, 288))
                paymaster := calldataload(add(paymasterOffset, add(userOp, 20)))
            }
            if (paymaster != permission.paymaster) revert("InvalidPaymaster");
        }
    }

    function _validateMerklePermission(
        Permission memory permission,
        bytes32[] memory proof,
        bytes32 permHash
    ) internal view {
        bool isValidProof = MerkleProof.verify(
            proof,
            permissionRegistry.operatorPermissions(
                address(this),
                permission.operator
            ),
            keccak256(bytes.concat(permHash))
        );
        if (!isValidProof) revert("Invalid Proof");
    }
}
