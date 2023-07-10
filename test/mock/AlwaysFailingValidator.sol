// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../../src/interfaces/IDataValidator.sol";

contract AlwaysFailingValidator is IDataValidator {
    function isValidData(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (bool) {
        return false;
    }
}
