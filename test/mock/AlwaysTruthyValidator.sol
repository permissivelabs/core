// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "../../src/interfaces/IDataValidator.sol";

contract AlwaysTruthyValidator is IDataValidator {
    function isValidData(UserOperation calldata, bytes32, uint256) external pure override returns (bool) {
        return true;
    }
}
