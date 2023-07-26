// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "safe-core/interfaces/Integrations.sol";
import "safe-core/interfaces/Manager.sol";
import "safe-core/DataTypes.sol";
import "account-abstraction/interfaces/INonceManager.sol";
import "../../../utils/Permission.sol";
import "../../../core/PermissionVerifier.sol";
import "../../../core/PermissionExecutor.sol";
import "bytes/BytesLib.sol";

contract SafePlugin is ISafeProtocolPlugin {
    using BytesLib for bytes;

    string public constant name = "Permissive";
    string public constant version = "v0.0.46";
    bool public constant requiresRootAccess = true;
    address immutable entryPoint;
    address immutable permissionVerifier;
    address immutable permissionExecutor;
    address immutable safeManager;

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

    function metadataProvider()
        external
        view
        override
        returns (uint256 providerType, bytes memory location)
    {}

    function validateUserOp(
        UserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        _requireFromEntryPoint();
        (address safe, UserOperation memory _userOp) = _getSafe(userOp);
        // PermissionVerifier
        bytes memory returnData = ISafeProtocolManager(safeManager)
            .executeRootAccess(
                ISafe(safe),
                SafeRootAccess({
                    action: SafeProtocolAction({
                        to: payable(permissionVerifier),
                        value: 0,
                        data: abi.encodeWithSelector(
                            PermissionVerifier.verify.selector,
                            _userOp,
                            userOpHash,
                            missingAccountFunds
                        )
                    }),
                    nonce: INonceManager(entryPoint).getNonce(address(this), 0),
                    metadataHash: bytes32(0)
                })
            );
        validationData = uint256(bytes32(returnData));
        _payPrefund(missingAccountFunds);
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata proof,
        uint256 gasFee
    ) external {
        _requireFromEntryPoint();
        ISafeProtocolManager(safeManager).executeRootAccess(
            ISafe(address(uint160(bytes20(func[0:20])))),
            SafeRootAccess({
                action: SafeProtocolAction({
                    to: payable(permissionExecutor),
                    value: 0,
                    data: abi.encodeWithSelector(
                        PermissionExecutor.execute.selector,
                        dest,
                        value,
                        func[20:],
                        permission,
                        proof,
                        gasFee
                    )
                }),
                nonce: INonceManager(entryPoint).getNonce(address(this), 0) + 1,
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

    function _getSafe(
        UserOperation memory userOp
    ) internal returns (address safe, UserOperation memory) {
        (
            address dest,
            uint256 value,
            bytes memory func,
            Permission memory perm,
            bytes32[] memory proof,
            uint256 gasFee
        ) = abi.decode(
                userOp.callData.slice(4, userOp.callData.length - 4),
                (address, uint256, bytes, Permission, bytes32[], uint256)
            );
        safe = address(bytes20(func.slice(0, 20)));
        func = func.slice(20, func.length - 20);
        userOp.callData = bytes.concat(
            userOp.callData.slice(0, 4),
            abi.encode(dest, value, func, perm, proof, gasFee)
        );
        return (safe, userOp);
    }
}
