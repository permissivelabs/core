// // SPDX-License-Identifier: SEE LICENSE IN LICENSE

// pragma solidity ^0.8.18;

// import "zerodev/validator/IValidator.sol";
// import "account-abstraction/interfaces/IEntryPoint.sol";
// import "../../core/FeeManager.sol";
// import "../../core/AllowanceCalldata.sol";
// import "../../interfaces/Permission.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// import "bytes/BytesLib.sol";

// struct PermissiveValidatorStorage {
//     address owner;
//     mapping(address => uint256) remainingFeeForOperator;
//     mapping(address => uint256) remainingValueForOperator;
//     mapping(address => bytes32) operatorPermissions;
//     mapping(bytes32 => uint256) remainingPermUsage;
// }

// contract PermissiveValidator is IKernelValidator {
//     using ECDSA for bytes32;
//     using BytesLib for bytes;
//     using PermissionLib for PermissionLib.Permission;

//     // Permissive storage
//     IEntryPoint public immutable entryPoint;
//     FeeManager private immutable feeManager;
//     // Zerodev Validator compatible storage
//     mapping(address => PermissiveValidatorStorage) permissiveValidatorStorage;

//     /*
//         EVENTS
//     */

//     // Zerodev
//     event OwnerChanged(address indexed oldOwner, address indexed owner);

//     // Permissive
//     event OperatorMutated(
//         address indexed operator,
//         bytes32 indexed oldPermissions,
//         bytes32 indexed newPermissions,
//         uint256 maxValue,
//         uint256 maxFee
//     );
//     event UserOpValidated(bytes32 indexed userOpHash, UserOperation userOp);

//     /*
//         CONSTRUCTOR
//     */

//     constructor(address _entryPoint, address payable _feeManager) {
//         entryPoint = IEntryPoint(_entryPoint);
//         feeManager = FeeManager(_feeManager);
//     }

//     /*
//         EXTERNALS
//     */

//     // Zerodev Validator

//     function enable(bytes calldata _data) external override {
//         address owner = address(bytes20(_data[0:20]));
//         address oldOwner = permissiveValidatorStorage[msg.sender].owner;
//         permissiveValidatorStorage[msg.sender].owner = owner;
//         emit OwnerChanged(oldOwner, owner);
//     }

//     function disable(bytes calldata) external pure override {
//         revert("Not implemented");
//     }

//     function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
//         external
//         override
//         returns (uint256 validationData)
//     {
//         bytes32 hash = userOpHash.toEthSignedMessageHash();
//         (,,, PermissionLib.Permission memory permission, bytes32[] memory proof, uint256 providedFee) =
//             abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[], uint256));
//         if (permission.operator != hash.recover(userOp.signature)) {
//             validationData = 1;
//         }
//         bytes32 permHash = permission.hash();
//         _validateMerklePermission(permission, proof, permHash);
//         _validatePermission(userOp, permission, permHash);
//         uint256 gasFee = computeGasFee(userOp);
//         if (providedFee != gasFee) revert("Invalid provided fee");
//         if (gasFee > permissiveValidatorStorage[msg.sender].remainingFeeForOperator[permission.operator]) {
//             revert("Exceeded Fees");
//         }
//         permissiveValidatorStorage[msg.sender].remainingFeeForOperator[permission.operator] -= gasFee;
//         emit UserOpValidated(userOpHash, userOp);
//     }

//     function validateSignature(bytes32 hash, bytes calldata signature) external view override returns (uint256) {
//         address owner = permissiveValidatorStorage[msg.sender].owner;
//         return owner == ECDSA.recover(hash, signature) ? 0 : 1;
//     }

//     // Permissive

//     function setOperatorPermissions(address operator, bytes32 merkleRootPermissions, uint256 maxValue, uint256 maxFee)
//         external
//     {
//         bytes32 oldValue = permissiveValidatorStorage[msg.sender].operatorPermissions[operator];
//         permissiveValidatorStorage[msg.sender].operatorPermissions[operator] = merkleRootPermissions;
//         permissiveValidatorStorage[msg.sender].remainingFeeForOperator[operator] = maxFee;
//         permissiveValidatorStorage[msg.sender].remainingValueForOperator[operator] = maxValue;
//         emit OperatorMutated(operator, oldValue, merkleRootPermissions, maxValue, maxFee);
//     }

//     function computeGasFee(UserOperation memory userOp) public pure returns (uint256 fee) {
//         unchecked {
//             uint256 mul = address(bytes20(userOp.paymasterAndData)) != address(0) ? 3 : 1;
//             uint256 requiredGas = userOp.callGasLimit + userOp.verificationGasLimit * mul + userOp.preVerificationGas;

//             fee = requiredGas * userOp.maxFeePerGas;
//         }
//     }

//     /* 
//         INTERNAL 
//     */

//     function _validatePermission(
//         UserOperation calldata userOp,
//         PermissionLib.Permission memory permission,
//         bytes32 permHash
//     ) internal {
//         (address to, uint256 value, bytes memory callData,,) =
//             abi.decode(userOp.callData[4:], (address, uint256, bytes, PermissionLib.Permission, bytes32[]));
//         if (permission.to != to) revert("InvalidTo");
//         if (permissiveValidatorStorage[msg.sender].remainingValueForOperator[permission.operator] < value) {
//             revert("ExceededValue");
//         }
//         permissiveValidatorStorage[msg.sender].remainingValueForOperator[permission.operator] -= value;
//         if (permission.maxUsage > 0) {
//             if (permission.maxUsage == 1) revert("OutOfPerms");
//             if (permissiveValidatorStorage[msg.sender].remainingPermUsage[permission.hash()] == 1) {
//                 revert("OutOfPerms2");
//             }
//             if (permissiveValidatorStorage[msg.sender].remainingPermUsage[permHash] == 0) {
//                 permissiveValidatorStorage[msg.sender].remainingPermUsage[permHash] = permission.maxUsage;
//             }
//             permissiveValidatorStorage[msg.sender].remainingPermUsage[permHash]--;
//         }
//         require(
//             AllowanceCalldata.isAllowedCalldata(permission.allowed_arguments, callData.slice(4, callData.length - 4))
//                 == true,
//             "Not allowed Calldata"
//         );
//         if (permission.selector != bytes4(callData)) revert("InvalidSelector");
//         if (permission.expiresAtUnix != 0 && permission.expiresAtBlock != 0) {
//             revert("InvalidPermission");
//         }
//         if (permission.paymaster != address(0)) {
//             address paymaster = address(0);
//             assembly {
//                 let paymasterOffset := calldataload(add(userOp, 288))
//                 paymaster := calldataload(add(paymasterOffset, add(userOp, 20)))
//             }
//             if (paymaster != permission.paymaster) revert("InvalidPaymaster");
//         }
//     }

//     function _validateMerklePermission(
//         PermissionLib.Permission memory permission,
//         bytes32[] memory proof,
//         bytes32 permHash
//     ) public view {
//         bool isValidProof = MerkleProof.verify(
//             proof,
//             permissiveValidatorStorage[msg.sender].operatorPermissions[permission.operator],
//             keccak256(bytes.concat(permHash))
//         );
//         if (!isValidProof) revert("Invalid Proof");
//     }
// }
