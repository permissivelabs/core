// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "../../interfaces/Permission.sol";
import "../../core/AllowanceCalldata.sol";
import "../../core/FeeManager.sol";
import "bytes/BytesLib.sol";

contract PermissiveExecutor {
    using BytesLib for bytes;
    using PermissionLib for PermissionLib.Permission;

    error ExpiredPermission(uint256 current, uint256 expiredAt);

    event PermissionUsed(
        bytes32 indexed permHash,
        address dest,
        uint256 value,
        bytes func,
        PermissionLib.Permission permission,
        uint256 gasFee
    );

    FeeManager private immutable feeManager;

    constructor(address payable _feeManager) {
        feeManager = FeeManager(_feeManager);
    }

    function executeWithPermissive(
        address dest,
        uint256 value,
        bytes memory func,
        PermissionLib.Permission calldata permission,
        // stores the proof, only used in validateUserOp
        bytes32[] calldata,
        uint256 gasFee
    ) external {
        if (permission.expiresAtUnix != 0) {
            if (block.timestamp >= permission.expiresAtUnix) {
                revert ExpiredPermission(block.timestamp, permission.expiresAtUnix);
            }
        } else if (permission.expiresAtBlock != 0) {
            if (block.number >= permission.expiresAtBlock) {
                revert ExpiredPermission(block.number, permission.expiresAtBlock);
            }
        }
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
}
