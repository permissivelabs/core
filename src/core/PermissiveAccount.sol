// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "account-abstraction/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/IPermissiveAccount.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./AllowanceCalldata.sol";
import "bytes/BytesLib.sol";
import "./FeeManager.sol";

// keccak256("OperatorPermissions(address operator,bytes32 merkleRootPermissions,uint256 maxValue,uint256 maxFee)")
bytes32 constant typedStruct = 0xcd3966ea44fb027b668c722656f7791caa71de9073b3cbb77585cc6fa97ce82e;

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable, EIP712 {
    using ECDSA for bytes32;
    using BytesLib for bytes;
    using PermissionLib for PermissionLib.Permission;

    mapping(address => uint256) public remainingFeeForOperator;
    mapping(address => uint256) public remainingValueForOperator;
    mapping(address => bytes32) public operatorPermissions;
    mapping(bytes32 => uint256) public remainingPermUsage;
    IEntryPoint private immutable _entryPoint;
    FeeManager private immutable feeManager;
    bool private _initialized;

    constructor(address __entryPoint, address payable _feeManager) EIP712("Permissive Account", "v0.0.3") {
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
        address operator,
        bytes32 merkleRootPermissions,
        uint256 maxValue,
        uint256 maxFee,
        bytes calldata signature
    ) external {
        bytes32 digest =
            _hashTypedDataV4(keccak256(abi.encode(typedStruct, operator, merkleRootPermissions, maxValue, maxFee)));
        address signer = ECDSA.recover(digest, signature);
        if (signer != owner()) revert NotAllowed(signer);
        bytes32 oldValue = operatorPermissions[operator];
        operatorPermissions[operator] = merkleRootPermissions;
        remainingFeeForOperator[operator] = maxFee;
        remainingValueForOperator[operator] = maxValue;
        emit OperatorMutated(operator, oldValue, merkleRootPermissions, maxValue, maxFee);
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        override(BaseAccount, IAccount)
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature)) {
            (,,, PermissionLib.Permission memory permission, bytes32[] memory proof, uint256 providedFee) =
                abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[], uint256));
            if (permission.operator != hash.recover(userOp.signature)) {
                validationData = SIG_VALIDATION_FAILED;
            }
            bytes32 permHash = permission.hash();
            _validateMerklePermission(permission, proof, permHash);
            _validatePermission(userOp, permission, permHash);
            uint256 gasFee = computeGasFee(userOp);
            if (providedFee != gasFee) revert("Invalid provided fee");
            if (gasFee > remainingFeeForOperator[permission.operator]) {
                revert("Exceeded Fees");
            }
            remainingFeeForOperator[permission.operator] -= gasFee;
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
        if (msg.sender != owner()) {
            if (permission.expiresAtUnix != 0) {
                if (block.timestamp >= permission.expiresAtUnix) {
                    revert ExpiredPermission(block.timestamp, permission.expiresAtUnix);
                }
            } else if (permission.expiresAtBlock != 0) {
                if (block.number >= permission.expiresAtBlock) {
                    revert ExpiredPermission(block.number, permission.expiresAtBlock);
                }
            }
        }
        payable(address(feeManager)).transfer((gasFee * feeManager.fee()) / 10000);
        (bool success, bytes memory result) = dest.call{value: value}(
            bytes.concat(func.slice(0, 4), AllowanceCalldata.RLPtoABI(func.slice(4, func.length - 4)))
        );
        emit PermissionUsed(permission.hash(), dest, value, func, permission, gasFee);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function computeGasFee(UserOperation memory userOp) public pure returns (uint256 fee) {
        unchecked {
            uint256 mul = address(bytes20(userOp.paymasterAndData)) != address(0) ? 3 : 1;
            uint256 requiredGas = userOp.callGasLimit + userOp.verificationGasLimit * mul + userOp.preVerificationGas;

            fee = requiredGas * userOp.maxFeePerGas;
        }
    }

    /* INTERNAL */

    function _hashTypedDataV4(bytes32 structHash) internal view override returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    function _validatePermission(
        UserOperation calldata userOp,
        PermissionLib.Permission memory permission,
        bytes32 permHash
    ) internal {
        (address to, uint256 value, bytes memory callData,,) =
            abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[]));
        if (permission.to != to) revert("InvalidTo");
        if (remainingValueForOperator[permission.operator] < value) {
            revert("ExceededValue");
        }
        remainingValueForOperator[permission.operator] -= value;
        if (permission.maxUsage > 0) {
            if (permission.maxUsage == 1) revert("OutOfPerms");
            if (remainingPermUsage[permission.hash()] == 1) {
                revert("OutOfPerms2");
            }
            if (remainingPermUsage[permHash] == 0) {
                remainingPermUsage[permHash] = permission.maxUsage;
            }
            remainingPermUsage[permHash]--;
        }
        require(
            AllowanceCalldata.isAllowedCalldata(permission.allowed_arguments, callData.slice(4, callData.length - 4))
                == true,
            "Not allowed Calldata"
        );
        if (permission.selector != bytes4(callData)) revert("InvalidSelector");
        if (permission.expiresAtUnix != 0 && permission.expiresAtBlock != 0) {
            revert("InvalidPermission");
        }
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
    ) public view {
        bool isValidProof =
            MerkleProof.verify(proof, operatorPermissions[permission.operator], keccak256(bytes.concat(permHash)));
        if (!isValidProof) revert("Invalid Proof");
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(msg.sender == address(entryPoint()) || msg.sender == owner(), "account: not from EntryPoint or owner");
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature)) {
            return SIG_VALIDATION_FAILED;
        }
        return 0;
    }

    function _payPrefund(uint256 missingAccountFunds) internal override {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes4) {
        if (ECDSA.recover(_hash, _signature) == owner()) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    receive() external payable {}
}
