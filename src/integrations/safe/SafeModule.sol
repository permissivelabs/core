// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

// SAFE related
import "./ISafe.sol";
import "./ISafeModule.sol";
// Permissive related
import "../../utils/Permission.sol";
import "../../core/PermissionVerifier.sol";
import "../../core/PermissionExecutor.sol";

contract SafeModule is ISafeModule {
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
        bytes32[] calldata,
        uint256 gasFee
    ) external {
        _requireFromEntryPointOrOwner();
        (bool success, bytes memory returnData) = address(permissionExecutor)
            .delegatecall(
                abi.encodeWithSelector(
                    PermissionExecutor.execute.selector,
                    dest,
                    value,
                    func,
                    permission,
                    gasFee
                )
            );
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
