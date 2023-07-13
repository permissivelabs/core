// // SPDX-License-Identifier: SEE LICENSE IN LICENSE

// pragma solidity ^0.8.18;

// // SAFE related
// import "safe/handler/CompatibilityFallbackHandler.sol";
// // Permissive related
// import "../../utils/Permission.sol";
// import "../../core/PermissionVerifier.sol";
// import "../../core/PermissionExecutor.sol";

// contract SafeFallbackHandler is CompatibilityFallbackHandler {
//     event OperatorMutated(
//         address indexed operator,
//         bytes32 indexed oldPermissions,
//         bytes32 indexed newPermissions
//     );
//     event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);
//     event PermissionUsed(
//         bytes32 indexed permHash,
//         address dest,
//         uint256 value,
//         bytes func,
//         Permission permission,
//         uint256 gasFee
//     );

//     IEntryPoint immutable entryPoint;
//     PermissionVerifier immutable permissionVerifier;
//     PermissionExecutor immutable permissionExecutor;

//     constructor(
//         IEntryPoint _entryPoint,
//         PermissionVerifier _verifier,
//         PermissionExecutor _executor
//     ) {
//         entryPoint = _entryPoint;
//         permissionVerifier = _verifier;
//         permissionExecutor = _executor;
//     }

//     // EXTERNAL FUNCTIONS

//     function validateUserOp(
//         UserOperation calldata userOp,
//         bytes32 userOpHash,
//         uint256 missingAccountFunds
//     ) external returns (uint256 validationData) {
//         console.log(msg.sender);
//         _requireFromEntryPointOrOwner();
//         // PermissionVerifier
//         (bool success, bytes memory returnData) = address(permissionVerifier)
//             .delegatecall(
//                 abi.encodeWithSelector(
//                     PermissionVerifier.verify.selector,
//                     userOp,
//                     userOpHash,
//                     missingAccountFunds
//                 )
//             );
//         if (!success) {
//             assembly {
//                 revert(add(returnData, 32), mload(returnData))
//             }
//         }
//         validationData = uint256(bytes32(returnData));
//         _payPrefund(missingAccountFunds);
//     }

//     function execute(
//         address dest,
//         uint256 value,
//         bytes memory func,
//         Permission calldata permission,
//         bytes32[] calldata proof,
//         uint256 gasFee
//     ) external {
//         _requireFromEntryPointOrOwner();
//         (bool success, bytes memory returnData) = address(permissionExecutor)
//             .delegatecall(
//                 abi.encodeWithSelector(
//                     PermissionExecutor.execute.selector,
//                     dest,
//                     value,
//                     func,
//                     permission,
//                     proof,
//                     gasFee
//                 )
//             );
//         if (!success) {
//             assembly {
//                 revert(add(returnData, 32), mload(returnData))
//             }
//         }
//     }

//     /* INTERNAL */

//     function _requireFromEntryPointOrOwner() internal view {
//         require(
//             msg.sender == address(entryPoint) || msg.sender == address(this),
//             "account: not from EntryPoint or owner"
//         );
//     }

//     function _payPrefund(uint256 missingAccountFunds) internal {
//         if (missingAccountFunds != 0) {
//             (bool success, ) = payable(msg.sender).call{
//                 value: missingAccountFunds,
//                 gas: type(uint256).max
//             }("");
//             (success);
//         }
//     }

//     receive() external payable {}
// }
