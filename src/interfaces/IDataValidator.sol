// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "account-abstraction/core/BaseAccount.sol";

/**
 * @title IDataValidator - A contract deployed by an external entity called to make custom checks on a user operation
 * @author Flydexo - @Flydex0
 * @notice This can be used for example to track the amount of granted ERC20 spent / swapped, etc...
 * @dev The DataValidator contract must respect ERC-4337 storage rules. That means the only storage accessible must have the userOp.sender as key.
 * @dev see https://eips.ethereum.org/EIPS/eip-4337#simulation
 */
interface IDataValidator {
    /**
     * @notice isValidData is called in the validateUserOp function of the PermissionVerifier contract
     * @param userOp The userOp
     * @dev userOp is formatted as integration agnostic, that means that if the SA (eg. Zerodev) requires a special field in the signature to determine which plugin to use, it is removed. Then the PermissionVerifier is called.
     * @param userOpHash The userOp hash
     * @param missingAccountFunds The funds the sender needs to pay to the EntryPoint
     * @return success Can revert to add additional logs and returns true if the userOp is considered valid
     */
    function isValidData(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (bool success);
}
