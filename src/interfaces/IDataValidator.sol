// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "account-abstraction/core/BaseAccount.sol";
import "./Permission.sol";

interface IDataValidator {
    function isValidData(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (bool);
}
