// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "./ISafe.sol";

interface ISafeModule {
    error InvalidSafe(address safe);
    error InvalidProof();
    error NotAllowed(address);
    error InvalidTo(address provided, address expected);
    error ExceededValue(uint256 value, uint256 max);
    error OutOfPerms(bytes32 perm);
    error ExceededFees(uint256 fee, uint256 maxFee);
    error InvalidPermission();
    error InvalidPaymaster(address provided, address expected);
    error InvalidSelector(bytes4 provided, bytes4 expected);
    error ExpiredPermission(uint current, uint expiredAt);

    event OperatorMutated(
        address operator,
        bytes32 oldPermissions,
        bytes32 newPermissions,
        uint256 maxValue,
        uint256 maxFee
    );
}
