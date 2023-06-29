// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "account-abstraction/core/BaseAccount.sol";
import "account-abstraction/core/Helpers.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../interfaces/IPermissiveAccount.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./AllowanceCalldata.sol";
import "bytes/BytesLib.sol";
import "./FeeManager.sol";
import "forge-std/console.sol";
import "../interfaces/IDataValidator.sol";

// keccak256("PermissionSet(address operator,bytes32 merkleRootPermissions)")
bytes32 constant typedStruct = 0xd7e1e23484f808c5620ce8d904e88d7540a3eeb37ac94e636726ed53571e4e3c;

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable, EIP712 {
    using ECDSA for bytes32;
    using BytesLib for bytes;
    using PermissionLib for PermissionLib.Permission;

    mapping(address => bytes32) public operatorPermissions;
    mapping(bytes32 => uint256) public remainingPermUsage;
    IEntryPoint private immutable _entryPoint;
    FeeManager private immutable feeManager;
    bool private _initialized;

    constructor(
        address __entryPoint,
        address payable _feeManager
    ) EIP712("Permissive Account", "v0.0.4") {
        _entryPoint = IEntryPoint(__entryPoint);
        feeManager = FeeManager(_feeManager);
    }

    /* GETTERS */

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    /* EXTERNAL FUNCTIONS */

    function initialize(address owner) external {
        require(!_initialized, "Contract already initialized");
        _initialized = true;
        _transferOwnership(owner);
    }

    function setOperatorPermissions(
        PermissionSet calldata permSet,
        bytes calldata signature
    ) external {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    typedStruct,
                    permSet.operator,
                    permSet.merkleRootPermissions
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        if (signer != owner()) revert("Not Allowed");
        bytes32 oldValue = operatorPermissions[permSet.operator];
        operatorPermissions[permSet.operator] = permSet.merkleRootPermissions;
        emit OperatorMutated(
            permSet.operator,
            oldValue,
            permSet.merkleRootPermissions
        );
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        override(BaseAccount, IAccount)
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature)) {
            (
                ,
                ,
                ,
                PermissionLib.Permission memory permission,
                bytes32[] memory proof,
                uint256 providedFee
            ) = abi.decode(
                    userOp.callData[4:],
                    (
                        address,
                        uint256,
                        bytes,
                        PermissionLib.Permission,
                        bytes32[],
                        uint256
                    )
                );
            if (permission.operator.code.length > 0) {
                try
                    IERC1271(permission.operator).isValidSignature(
                        hash,
                        userOp.signature
                    )
                returns (bytes4 magicValue) {
                    validationData = _packValidationData(
                        ValidationData(
                            magicValue == IERC1271.isValidSignature.selector
                                ? address(0)
                                : address(1),
                            permission.validAfter,
                            permission.validUntil
                        )
                    );
                } catch {
                    validationData = _packValidationData(
                        ValidationData(
                            address(1),
                            permission.validAfter,
                            permission.validUntil
                        )
                    );
                }
            } else if (permission.operator != hash.recover(userOp.signature)) {
                return SIG_VALIDATION_FAILED;
            } else {
                validationData = _packValidationData(
                    ValidationData(
                        address(0),
                        permission.validAfter,
                        permission.validUntil
                    )
                );
            }
            bytes32 permHash = permission.hash();
            _validateMerklePermission(permission, proof, permHash);
            _validatePermission(userOp, permission, permHash);
            _validateData(userOp, userOpHash, missingAccountFunds, permission);
            uint256 gasFee = computeGasFee(userOp);
            if (providedFee != gasFee) revert("Invalid provided fee");
        }
        _payPrefund(missingAccountFunds);
        emit UserOpValidated(userOpHash, userOp);
    }

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        PermissionLib.Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata,
        uint256 gasFee
    ) external {
        _requireFromEntryPointOrOwner();
        payable(address(feeManager)).transfer(
            (gasFee * feeManager.fee()) / 10000
        );
        (bool success, bytes memory result) = dest.call{value: value}(
            bytes.concat(
                func.slice(0, 4),
                AllowanceCalldata.RLPtoABI(func.slice(4, func.length - 4))
            )
        );
        emit PermissionUsed(
            permission.hash(),
            dest,
            value,
            func,
            permission,
            gasFee
        );
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function computeGasFee(
        UserOperation memory userOp
    ) public pure returns (uint256 fee) {
        unchecked {
            uint256 mul = address(bytes20(userOp.paymasterAndData)) !=
                address(0)
                ? 3
                : 1;
            uint256 requiredGas = userOp.callGasLimit +
                userOp.verificationGasLimit *
                mul +
                userOp.preVerificationGas;

            fee = requiredGas * userOp.maxFeePerGas;
        }
    }

    /* INTERNAL */

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view override returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    function _validateData(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        PermissionLib.Permission memory permission
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
        PermissionLib.Permission memory permission,
        bytes32 permHash
    ) internal {
        (address to, uint256 value, bytes memory callData, , ) = abi.decode(
            userOp.callData[4:],
            (address, uint256, bytes, PermissionLib.Permission, bytes32[])
        );
        if (permission.to != to) revert("InvalidTo");
        uint256 rPermU = remainingPermUsage[permHash];
        if (permission.maxUsage > 0) {
            if (permission.maxUsage == 1) revert("OutOfPerms");
            if (rPermU == 1) {
                revert("OutOfPerms2");
            }
            if (rPermU == 0) {
                rPermU = permission.maxUsage;
            }
            rPermU--;
            remainingPermUsage[permHash] = rPermU;
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
        PermissionLib.Permission memory permission,
        bytes32[] memory proof,
        bytes32 permHash
    ) internal view {
        bool isValidProof = MerkleProof.verify(
            proof,
            operatorPermissions[permission.operator],
            keccak256(bytes.concat(permHash))
        );
        if (!isValidProof) revert("Invalid Proof");
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner(),
            "account: not from EntryPoint or owner"
        );
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature)) {
            return SIG_VALIDATION_FAILED;
        }
        return 0;
    }

    function _payPrefund(uint256 missingAccountFunds) internal override {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            (success);
        }
    }

    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view returns (bytes4) {
        if (ECDSA.recover(_hash, _signature) == owner()) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    receive() external payable {}
}
