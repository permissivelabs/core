// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "zerodev/validator/IValidator.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "account-abstraction/core/Helpers.sol";
import "../../core/FeeManager.sol";
import "../../core/AllowanceCalldata.sol";
import "../../interfaces/Permission.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "bytes/BytesLib.sol";
import "../../interfaces/IDataValidator.sol";
import "../../interfaces/IPermissiveAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// keccak256("PermissionSet(address operator,bytes32 merkleRootPermissions)")
bytes32 constant typedStruct = 0xd7e1e23484f808c5620ce8d904e88d7540a3eeb37ac94e636726ed53571e4e3c;

struct PermissiveValidatorStorage {
    address owner;
}

contract PermissiveValidator is IKernelValidator, EIP712 {
    using ECDSA for bytes32;
    using BytesLib for bytes;
    using PermissionLib for PermissionLib.Permission;

    // Permissive storage
    IEntryPoint public immutable entryPoint;
    FeeManager private immutable feeManager;
    // Zerodev Validator compatible storage
    mapping(address => PermissiveValidatorStorage) permissiveValidatorStorage;
    mapping(address => mapping(address => bytes32)) operatorPermissions;
    mapping(address => mapping(bytes32 => uint256)) remainingPermUsage;

    /*
        EVENTS
    */

    // Zerodev
    event OwnerChanged(address indexed oldOwner, address indexed owner);

    // Permissive
    event OperatorMutated(address indexed operator, bytes32 indexed oldPermissions, bytes32 indexed newPermissions);
    event UserOpValidated(bytes32 indexed userOpHash, UserOperation userOp);

    /*
        CONSTRUCTOR
    */

    constructor(address _entryPoint, address payable _feeManager) EIP712("Permissive x Zerodev", "v0.0.4") {
        entryPoint = IEntryPoint(_entryPoint);
        feeManager = FeeManager(_feeManager);
    }

    /*
        EXTERNALS
    */

    // Zerodev Validator

    function enable(bytes calldata _data) external override {
        address owner = address(bytes20(_data[0:20]));
        address oldOwner = permissiveValidatorStorage[msg.sender].owner;
        permissiveValidatorStorage[msg.sender].owner = owner;
        emit OwnerChanged(oldOwner, owner);
    }

    function disable(bytes calldata) external pure override {
        revert("Not implemented");
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        (,,, PermissionLib.Permission memory permission, bytes32[] memory proof, uint256 providedFee) =
            abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[], uint256));
        uint256 operatorCodeSize;
        address op = permission.operator;
        assembly {
            operatorCodeSize := extcodesize(op)
        }
        if (operatorCodeSize > 0) {
            validationData =
                _packValidationData(ValidationData(permission.operator, permission.validAfter, permission.validUntil));
        } else if (permission.operator != hash.recover(userOp.signature)) {
            return 1;
        } else {
            validationData =
                _packValidationData(ValidationData(address(0), permission.validAfter, permission.validUntil));
        }
        bytes32 permHash = permission.hash();
        _validateMerklePermission(permission, proof, permHash);
        _validatePermission(userOp, permission, permHash);
        _validateData(permission);
        uint256 gasFee = computeGasFee(userOp);
        if (providedFee != gasFee) revert("Invalid provided fee");
        emit UserOpValidated(userOpHash, userOp);
    }

    function validateSignature(bytes32 hash, bytes calldata signature) external view override returns (uint256) {}

    // Permissive

    function setOperatorPermissions(PermissionSet calldata permSet, bytes calldata signature) external {
        bytes32 digest =
            _hashTypedDataV4(keccak256(abi.encode(typedStruct, permSet.operator, permSet.merkleRootPermissions)));
        address signer = ECDSA.recover(digest, signature);
        bytes32 oldValue = operatorPermissions[signer][permSet.operator];
        operatorPermissions[signer][permSet.operator] = permSet.merkleRootPermissions;
        emit OperatorMutated(permSet.operator, oldValue, permSet.merkleRootPermissions);
    }

    function computeGasFee(UserOperation memory userOp) public pure returns (uint256 fee) {
        unchecked {
            uint256 mul = address(bytes20(userOp.paymasterAndData)) != address(0) ? 3 : 1;
            uint256 requiredGas = userOp.callGasLimit + userOp.verificationGasLimit * mul + userOp.preVerificationGas;

            fee = requiredGas * userOp.maxFeePerGas;
        }
    }

    /*
        INTERNAL
    */

    function _validateData(PermissionLib.Permission memory permission) internal view {
        if (
            permission.dataValidation.validator != address(0)
                && !IDataValidator(permission.dataValidation.validator).isValidData(
                    permission.dataValidation.target, permission.dataValidation.data
                )
        ) {
            revert("Invalid data");
        }
    }

    function _validatePermission(
        UserOperation calldata userOp,
        PermissionLib.Permission memory permission,
        bytes32 permHash
    ) internal {
        (address to, uint256 value, bytes memory callData,,) =
            abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[]));
        if (permission.to != to) revert("InvalidTo");
        if (permission.maxUsage > 0) {
            if (permission.maxUsage == 1) revert("OutOfPerms");
            if (remainingPermUsage[msg.sender][permission.hash()] == 1) {
                revert("OutOfPerms2");
            }
            if (remainingPermUsage[msg.sender][permHash] == 0) {
                remainingPermUsage[msg.sender][permHash] = permission.maxUsage;
            }
            remainingPermUsage[msg.sender][permHash]--;
        }
        require(
            AllowanceCalldata.isAllowedCalldata(
                permission.allowed_arguments, callData.slice(4, callData.length - 4), value
            ) == true,
            "Not allowed Calldata"
        );
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
        PermissionLib.Permission memory permission,
        bytes32[] memory proof,
        bytes32 permHash
    ) internal view {
        bool isValidProof = MerkleProof.verify(
            proof, operatorPermissions[msg.sender][permission.operator], keccak256(bytes.concat(permHash))
        );
        if (!isValidProof) revert("Invalid Proof");
    }

    function _hashTypedDataV4(bytes32 structHash) internal view virtual override returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}
