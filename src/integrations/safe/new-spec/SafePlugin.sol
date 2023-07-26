// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "safe-core/interfaces/Integrations.sol";
import "safe-core/interfaces/Manager.sol";
import "safe-core/DataTypes.sol";
import "account-abstraction/interfaces/INonceManager.sol";
import "../../../utils/Permission.sol";
import "../../../core/PermissionVerifier.sol";
import "../../../core/PermissionExecutor.sol";

contract SafePlugin is ISafeProtocolPlugin {
    string public constant name = "Permissive";
    string public constant version = "v0.0.46";
    bool public constant requiresRootAccess = true;
    address immutable entryPoint;
    address immutable permissionVerifier;
    address immutable permissionExecutor;
    address immutable safeManager;
    address safe;

    constructor(
        address _entryPoint,
        address _permissionVerifier,
        address _safeManager,
        address _permissionExecutor
    ) {
        entryPoint = _entryPoint;
        permissionExecutor = _permissionExecutor;
        permissionVerifier = _permissionVerifier;
        safeManager = _safeManager;
    }

    function initialize(address _safe) external {
        require(safe == address(0));
        safe = _safe;
    }

    function metadataProvider()
        external
        view
        override
        returns (uint256 providerType, bytes memory location)
    {}

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        _requireFromEntryPoint();
        // PermissionVerifier
        (bool success, bytes memory returnData) = permissionVerifier
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
        _requireFromEntryPoint();
        ISafeProtocolManager(safeManager).executeRootAccess(
            ISafe(safe),
            SafeRootAccess({
                action: SafeProtocolAction({
                    to: payable(permissionExecutor),
                    value: 0,
                    data: abi.encodeWithSelector(
                        PermissionExecutor.execute.selector,
                        dest,
                        value,
                        func,
                        permission,
                        proof,
                        gasFee
                    )
                }),
                nonce: INonceManager(entryPoint).getNonce(address(this), 0),
                metadataHash: bytes32(0)
            })
        );
    }

    /* INTERNAL */

    function _requireFromEntryPoint() internal view {
        require(
            msg.sender == address(entryPoint),
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
}
