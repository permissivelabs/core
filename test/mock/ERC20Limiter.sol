// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../../src/interfaces/IDataValidator.sol";
import "../../src/core/AllowanceCalldata.sol";
import "bytes/BytesLib.sol";
import "forge-std/console.sol";

struct Limit {
    address token;
    uint256 limit;
}

contract ERC20Limiter is IDataValidator {
    using BytesLib for bytes;

    mapping(address owner => mapping(address token => uint256 limit))
        public limit;

    function setLimits(Limit[] calldata limits) external {
        for (uint i = 0; i < limits.length; i++) {
            limit[msg.sender][limits[i].token] = limits[i].limit;
        }
    }

    function isValidData(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (bool) {
        (
            ,
            ,
            bytes memory func,
            PermissionLib.Permission memory permission,
            ,

        ) = abi.decode(
                userOp.callData[4:],
                (
                    address,
                    uint256,
                    bytes,
                    PermissionLib.Permission,
                    bytes32[],
                    uint256
                )
            );
        (, uint256 amount) = abi.decode(
            AllowanceCalldata.RLPtoABI(func.slice(4, func.length - 4)),
            (address, uint256)
        );
        if (limit[msg.sender][permission.to] < amount) return false;
        limit[msg.sender][permission.to] -= amount;
        return true;
    }
}
