// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "account-abstraction/core/BaseAccount.sol";
import "../interfaces/IPermissiveAccount.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./AllowanceCalldata.sol";
import "bytes/BytesLib.sol";

contract PermissiveAccount is BaseAccount, IPermissiveAccount, Ownable {
    using ECDSA for bytes32;
    using BytesLib for bytes;
    mapping(address => uint256) public remainingFeeForOperator;
    mapping(address => uint256) public remainingValueForOperator;
    mapping(address => bytes32) public operatorPermissions;
    IEntryPoint private immutable _entryPoint;
    uint96 private _nonce;
    bool private _initialized;

    struct EIP712Struct {
        bytes32 permissionHash;
    }

    constructor(address __entryPoint) {
        _entryPoint = IEntryPoint(__entryPoint);
    }

    /* GETTERS */

    function nonce() public view override returns (uint256) {
        return _nonce;
    }

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
        uint256 maxFee
    ) external {
        _requireFromEntryPointOrOwner();
        bytes32 oldValue = operatorPermissions[operator];
        operatorPermissions[operator] = merkleRootPermissions;
        remainingFeeForOperator[operator] = maxFee;
        remainingValueForOperator[operator] = maxValue;
        emit OperatorMutated(operator, oldValue, merkleRootPermissions);
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address,
        uint256 missingAccountFunds
    )
        external
        override(BaseAccount, IAccount)
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        if (userOp.initCode.length == 0) {
            _validateAndUpdateNonce(userOp);
        }
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature)) {
            (, , , Permission memory permission, bytes32[] memory proof) = abi
                .decode(
                    userOp.callData[4:],
                    (address, uint256, bytes, Permission, bytes32[])
                );
            if (permission.operator != hash.recover(userOp.signature))
                validationData = SIG_VALIDATION_FAILED;
            _validateMerklePermission(permission, proof);
            _validatePermission(userOp, permission);
            if (
                missingAccountFunds >
                remainingFeeForOperator[permission.operator]
            ) {
                revert ExceededFees(
                    missingAccountFunds,
                    remainingFeeForOperator[permission.operator]
                );
            }
            remainingFeeForOperator[permission.operator] -= missingAccountFunds;
        }
        _payPrefund(missingAccountFunds);
    }

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata
    ) external {
        _requireFromEntryPointOrOwner();
        if (msg.sender != owner()) {
            if (permission.expiresAtUnix != 0) {
                if (block.timestamp >= permission.expiresAtUnix)
                    revert ExpiredPermission(
                        block.timestamp,
                        permission.expiresAtUnix
                    );
            } else if (permission.expiresAtBlock != 0) {
                if (block.number >= permission.expiresAtBlock)
                    revert ExpiredPermission(
                        block.number,
                        permission.expiresAtBlock
                    );
            }
        }
        (bool success, bytes memory result) = dest.call{value: value}(
            bytes.concat(
                func.slice(0, 4),
                AllowanceCalldata.RLPtoABI(func.slice(4, func.length - 4))
            )
        );
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /* INTERNAL */

    function _validatePermission(
        UserOperation calldata userOp,
        Permission memory permission
    ) internal {
        (address to, uint256 value, bytes memory callData, , ) = abi.decode(
            userOp.callData[4:],
            (address, uint256, bytes, Permission, bytes32[])
        );
        if (permission.to != to) revert InvalidTo(to, permission.to);
        if (remainingValueForOperator[permission.operator] < value)
            revert ExceededValue(
                value,
                remainingValueForOperator[permission.operator]
            );
        remainingValueForOperator[permission.operator] -= value;
        assert(
            AllowanceCalldata.isAllowedCalldata(
                permission.allowed_arguments,
                callData.slice(4, callData.length - 4)
            ) == true
        );
        if (permission.selector != bytes4(callData))
            revert InvalidSelector(bytes4(callData), permission.selector);
        if (permission.expiresAtUnix != 0 && permission.expiresAtBlock != 0)
            revert InvalidPermission();
        if (permission.paymaster != address(0)) {
            address paymaster = address(0);
            assembly {
                let paymasterOffset := calldataload(add(userOp, 288))
                paymaster := calldataload(add(paymasterOffset, add(userOp, 20)))
            }
            if (paymaster != permission.paymaster)
                revert InvalidPaymaster(paymaster, permission.paymaster);
        }
    }

    function _validateMerklePermission(
        Permission memory permission,
        bytes32[] memory proof
    ) public view {
        bytes32 permHash = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
                permission.paymaster,
                permission.expiresAtUnix,
                permission.expiresAtBlock
            )
        );
        bool isValidProof = MerkleProof.verify(
            proof,
            operatorPermissions[permission.operator],
            permHash
        );
        if (!isValidProof) revert InvalidProof();
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner(),
            "account: not from EntryPoint or owner"
        );
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address
    ) internal view override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner() != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override {
        require(++_nonce == userOp.nonce, "account: invalid nonce");
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

    receive() external payable {}
}
