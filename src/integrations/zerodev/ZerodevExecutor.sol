// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "../../utils/Permission.sol";
import "../../core/PermissionExecutor.sol";

contract ZerodevExecutor {
    PermissionExecutor immutable permissionExecutor;

    constructor(PermissionExecutor executor) {
        permissionExecutor = executor;
    }

    function execute(
        address dest,
        uint256 value,
        bytes memory func,
        Permission calldata permission,
        bytes32[] calldata,
        uint256 gasFee
    ) external {
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
}
