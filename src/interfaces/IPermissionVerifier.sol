// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "account-abstraction/interfaces/UserOperation.sol";

interface IPermissionVerifier {
    event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);

    function verify(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData);

    function computeGasFee(UserOperation memory userOp) external pure returns (uint256 fee);
}
