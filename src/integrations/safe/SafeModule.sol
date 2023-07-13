// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

// SAFE related
import "./ISafe.sol";
// Permissive related
import "../../utils/Permission.sol";
import "../../core/PermissionVerifier.sol";
import "../../core/PermissionExecutor.sol";

contract SafeModule {
    event OperatorMutated(
        address indexed operator,
        bytes32 indexed oldPermissions,
        bytes32 indexed newPermissions
    );
    event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);
    event PermissionUsed(
        bytes32 indexed permHash,
        address dest,
        uint256 value,
        bytes func,
        Permission permission,
        uint256 gasFee
    );
    event NewSafe(address safe);

    ISafe public safe;

    IEntryPoint immutable entryPoint;
    PermissionVerifier immutable permissionVerifier;
    PermissionExecutor immutable permissionExecutor;

    constructor(
        IEntryPoint _entryPoint,
        PermissionVerifier _verifier,
        PermissionExecutor _executor
    ) {
        entryPoint = _entryPoint;
        permissionVerifier = _verifier;
        permissionExecutor = _executor;
    }

    // SAFE SPECIFIC

    function setSafe(address _safe) external {
        _onlySafe();
        safe = ISafe(_safe);
        emit NewSafe(_safe);
    }

    // EXTERNAL FUNCTIONS

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        _requireFromEntryPointOrOwner();
        // PermissionVerifier
        (bool success, bytes memory returnData) = address(permissionVerifier)
            .delegatecall(
                abi.encodeWithSelector(
                    PermissionVerifier.verify.selector,
                    userOp,
                    userOpHash,
                    missingAccountFunds
                )
            );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        validationData = uint256(bytes32(returnData));
        _payPrefund(missingAccountFunds);
    }

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata proof,
        uint256 gasFee
    ) external {
        _requireFromEntryPointOrOwner();
        (bool success, bytes memory returnData) = safe
            .execTransactionFromModuleReturnData(
                address(permissionExecutor),
                0,
                abi.encodeWithSelector(
                    PermissionExecutor.execute.selector,
                    dest,
                    value,
                    func,
                    permission,
                    proof,
                    gasFee
                ),
                ISafe.Operation.DelegateCall
            );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    function executeAsModule(
        address dest,
        uint256 value,
        bytes memory data
    ) external {
        require(msg.sender == address(safe), "account: not from owner");
        (bool success, bytes memory returnData) = dest.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    /* INTERNAL */

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

    receive() external payable {}

    function _onlySafe() internal view {
        if (address(safe) == address(0)) return;
        if (msg.sender != address(safe)) revert("Not Allowed");
    }
}
