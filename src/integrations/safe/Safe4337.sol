// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// SAFE related
import "./ISafe.sol";
import "safe/libraries/SafeStorage.sol";
// Permissive related
import "../../utils/Permission.sol";
import "../../core/PermissionVerifier.sol";
import "../../core/PermissionExecutor.sol";

contract Safe4337Module is SafeStorage {
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

    address immutable myAddress;
    IEntryPoint immutable entryPoint;
    PermissionVerifier immutable permissionVerifier;
    PermissionExecutor immutable permissionExecutor;

    address internal constant SENTINEL_MODULES = address(0x1);

    constructor(
        IEntryPoint _entryPoint,
        PermissionVerifier verifier,
        PermissionExecutor executor
    ) {
        entryPoint = _entryPoint;
        myAddress = address(this);
        permissionVerifier = verifier;
        permissionExecutor = executor;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        require(userOp.sender == msg.sender, "msg.sender is not userOp.sender");
        (bool success, bytes memory returnData) = ISafe(msg.sender)
            .execTransactionFromModuleReturnData(
                address(permissionVerifier),
                0,
                abi.encodeWithSelector(
                    PermissionVerifier.verify.selector,
                    userOp,
                    userOpHash,
                    missingAccountFunds
                ),
                ISafe.Operation.DelegateCall
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
        (bool success, bytes memory returnData) = ISafe(msg.sender)
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

    function enableMyself() public {
        require(myAddress != address(this), "You need to DELEGATECALL, sir");
        require(modules[myAddress] == address(0), "GS102");
        modules[myAddress] = modules[SENTINEL_MODULES];
        modules[SENTINEL_MODULES] = myAddress;
    }

    /* INTERNAL */

    function _payPrefund(uint256 missingAccountFunds) internal {
        (bool success, bytes memory result) = ISafe(msg.sender)
            .execTransactionFromModuleReturnData(
                address(entryPoint),
                missingAccountFunds,
                hex"",
                ISafe.Operation.Call
            );
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        // if (missingAccountFunds != 0) {
        //     (bool success, ) = payable(msg.sender).call{
        //         value: missingAccountFunds,
        //         gas: type(uint256).max
        //     }("");
        //     (success);
        // }
    }

    receive() external payable {}

    function _onlySafe() internal view {
        if (msg.sender != address(this)) revert("Not Allowed");
    }
}
