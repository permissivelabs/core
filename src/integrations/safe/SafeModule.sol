// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

// SAFE related
import "./ISafe.sol";
import "./ISafeModule.sol";
// Permissive related
import "account-abstraction/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "../../interfaces/Permission.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../../core/AllowanceCalldata.sol";
import "bytes/BytesLib.sol";
import "../../core/FeeManager.sol";

contract SafeModule is ISafeModule {
    ISafe public safe;
    using ECDSA for bytes32;
    using BytesLib for bytes;
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

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions,
        uint256 maxValue,
        uint256 maxFee
    ) external {
        _onlySafe();
        bytes32 oldValue = operatorPermissions[operator];
        operatorPermissions[operator] = merkleRootPermissions;
        remainingFeeForOperator[operator] = maxFee;
        remainingValueForOperator[operator] = maxValue;
        emit OperatorMutated(
            operator,
            oldValue,
            merkleRootPermissions,
            maxValue,
            maxFee
        );
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        _requireFromEntryPoint();
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
        if (permission.operator != hash.recover(userOp.signature)) {
            validationData = 1;
        }
        bytes32 permHash = hashPerm(permission);
        _validateMerklePermission(permission, proof, permHash);
        _validatePermission(userOp, permission, permHash);
        uint gasFee = computeGasFee(userOp);
        if (providedFee != gasFee) revert("Invalid provided fee");
        if (gasFee > remainingFeeForOperator[permission.operator]) {
            revert("Exceeded Fees");
        }
        remainingFeeForOperator[permission.operator] -= gasFee;
        _payPrefund(missingAccountFunds);
    }

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata,
        uint256 gasFee
    ) external {
        _requireFromEntryPointOrOwner();
        if (msg.sender != address(safe)) {
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
        payable(address(feeManager)).transfer(
            (gasFee * feeManager.fee()) / 10000
        );
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

    function hashPerm(
        Permission memory permission
    ) internal pure returns (bytes32 permHash) {
        permHash = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
                permission.allowed_arguments,
                permission.paymaster,
                permission.expiresAtUnix,
                permission.expiresAtBlock,
                permission.maxUsage
            )
        );
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
        if (remainingValueForOperator[permission.operator] < value)
            revert("ExceededValue");
        remainingValueForOperator[permission.operator] -= value;
        if (permission.maxUsage > 0) {
            if (permission.maxUsage == 1) revert("OutOfPerms");
            if (remainingPermUsage[hashPerm(permission)] == 1)
                revert("OutOfPerms2");
            if (remainingPermUsage[permHash] == 0) {
                remainingPermUsage[permHash] = permission.maxUsage;
            }
            remainingPermUsage[permHash]--;
        }
        require(
            AllowanceCalldata.isAllowedCalldata(
                permission.allowed_arguments,
                callData.slice(4, callData.length - 4)
            ) == true,
            "Not allowed Calldata"
        );
        if (permission.selector != bytes4(callData)) revert("InvalidSelector");
        if (permission.expiresAtUnix != 0 && permission.expiresAtBlock != 0)
            revert("InvalidPermission");
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
    ) public view {
        bool isValidProof = MerkleProof.verify(
            proof,
            operatorPermissions[permission.operator],
            keccak256(bytes.concat(permHash))
        );
        if (!isValidProof) revert("Invalid Proof");
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint) || msg.sender == address(safe),
            "account: not from EntryPoint or owner"
        );
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            (success);
        }
    }

    function recoverSigner(
        bytes32 _hash,
        bytes memory _signature
    ) internal pure returns (address signer) {
        require(
            _signature.length == 65,
            "SignatureValidator#recoverSigner: invalid signature length"
        );
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := and(mload(add(_signature, 65)), 255)
        }
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert(
                "SignatureValidator#recoverSigner: invalid signature 's' value"
            );
        }
        if (v != 27 && v != 28) {
            revert(
                "SignatureValidator#recoverSigner: invalid signature 'v' value"
            );
        }
        signer = ecrecover(_hash, v, r, s);
        require(
            signer != address(0x0),
            "SignatureValidator#recoverSigner: INVALID_SIGNER"
        );

        return signer;
    }

    function isValidSignature(
        bytes32,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xffffffff;
    }

    receive() external payable {}

    function _onlySafe() internal view {
        if (address(safe) == address(0)) return;
        if (msg.sender != address(safe)) revert NotAllowed(msg.sender);
    }

    function _requireFromEntryPoint() internal view virtual {
        require(
            msg.sender == address(entryPoint),
            "account: not from EntryPoint"
        );
    }
}
