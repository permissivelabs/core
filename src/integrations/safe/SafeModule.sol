// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

// SAFE related
import "./ISafe.sol";
import "./ISafeModule.sol";
// Permissive related
import "bytes/BytesLib.sol";
import "account-abstraction/core/BaseAccount.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../../core/AllowanceCalldata.sol";
import "../../core/FeeManager.sol";
import "../../interfaces/IPermissiveAccount.sol";
import "../../interfaces/IDataValidator.sol";
import "../../interfaces/Permission.sol";

contract SafeModule is ISafeModule {
    ISafe public safe;

    using ECDSA for bytes32;
    using BytesLib for bytes;
    using PermissionLib for PermissionLib.Permission;

    mapping(address => uint256) public remainingFeeForOperator;
    mapping(address => uint256) public remainingValueForOperator;
    mapping(address => bytes32) public operatorPermissions;
    mapping(bytes32 => uint256) public remainingPermUsage;
    IEntryPoint public immutable entryPoint;
    FeeManager private immutable feeManager;

    constructor(address _entryPoint, address payable _feeManager) {
        entryPoint = IEntryPoint(_entryPoint);
        feeManager = FeeManager(_feeManager);
    }

    function getNonce() public view virtual returns (uint256) {
        return entryPoint.getNonce(address(this), 0);
    }

    // SAFE SPECIFIC

    function setSafe(address _safe) external {
        _onlySafe();
        safe = ISafe(_safe);
        emit NewSafe(_safe);
    }

    // EXTERNAL FUNCTIONS

    function setOperatorPermissions(PermissionSet calldata permSet) external {
        _onlySafe();
        bytes32 oldValue = operatorPermissions[permSet.operator];
        operatorPermissions[permSet.operator] = permSet.merkleRootPermissions;
        emit OperatorMutated(permSet.operator, oldValue, permSet.merkleRootPermissions);
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        (,,, PermissionLib.Permission memory permission, bytes32[] memory proof, uint256 providedFee) =
            abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[], uint256));
        if (permission.operator.code.length > 0) {
            try IERC1271(permission.operator).isValidSignature(hash, userOp.signature) returns (bytes4 magicValue) {
                validationData = _packValidationData(
                    ValidationData(
                        magicValue == IERC1271.isValidSignature.selector ? address(0) : address(1),
                        permission.validAfter,
                        permission.validUntil
                    )
                );
            } catch {
                validationData =
                    _packValidationData(ValidationData(address(1), permission.validAfter, permission.validUntil));
            }
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
                permission.allowed_arguments, callData.slice(4, callData.length - 4), value
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
        bool isValidProof =
            MerkleProof.verify(proof, operatorPermissions[permission.operator], keccak256(bytes.concat(permHash)));
        if (!isValidProof) revert("Invalid Proof");
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint) || msg.sender == address(safe), "account: not from EntryPoint or owner"
        );
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    receive() external payable {}

    function _onlySafe() internal view {
        if (address(safe) == address(0)) return;
        if (msg.sender != address(safe)) revert("Not Allowed");
    }

    function _requireFromEntryPoint() internal view virtual {
        require(msg.sender == address(entryPoint), "account: not from EntryPoint");
    }
}
