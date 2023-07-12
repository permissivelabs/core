// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "account-abstraction/interfaces/UserOperation.sol";

/**
 * @title IPermissionVerifier - Contract in change of the validation phase of the UserOperation.
 * @author Flydexo - @Flydex0
 * @notice Contract only callable with delegatecall by the account itself or it's module or plugin
 */
interface IPermissionVerifier {
    /**
     * @notice PermissionVerified - Emitted when a permission is successfully verified
     * @param userOpHash The hash of the userOperation
     * @param userOp The userOperation
     */
    event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);

    /**
     * @notice verify - Function that make all the Permissive related checks on the userOperation.
     * @param userOp The userOperation
     * @param userOpHash The userOperation hash
     * @param missingAccountFunds The funds the sender needs to pay to the EntryPoint
     * @return validationData The validation data that signals are valid / invalid signature and the timespan of the permission
     * @dev For validationData specs see see https://eips.ethereum.org/EIPS/eip-4337#definitions
     */
    function verify(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData);

    /**
     * @notice computeGasFee - Function called to compute the gasFee of the userOperation depending on all the gas parameters of the operation.
     * @dev Use this function to determine the fee in the execute function
     * @param userOp The userOperation
     */
    function computeGasFee(UserOperation memory userOp) external pure returns (uint256 fee);
}
