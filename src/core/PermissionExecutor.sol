// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../utils/AllowanceCalldata.sol";
import "../interfaces/IPermissionExecutor.sol";
import "./FeeManager.sol";
import "bytes/BytesLib.sol";

/**
 * @dev see {IPermissionExecutor}
 */
contract PermissionExecutor is IPermissionExecutor {
    using BytesLib for bytes;
    using PermissionLib for Permission;

    FeeManager private immutable feeManager;

    constructor(FeeManager _feeManager) {
        feeManager = _feeManager;
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func,
        Permission calldata permission,
        bytes32[] calldata,
        uint256 gasFee
    ) external {
        feeManager.pay{value: (gasFee * feeManager.fee()) / 10000}();
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
        emit PermissionUsed(
            permission.hash(),
            dest,
            value,
            func,
            permission,
            gasFee
        );
        assembly {
            return(add(result, 32), mload(result))
        }
    }
}
