// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.19;

import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "./Permission.sol";

interface IPermissiveAccount is IAccount {
    error InvalidProof();
    error NotAllowed(address);
    error InvalidTo(address provided, address expected);
    error ExceededValue(uint256 value, uint256 max);
    error ExceededFees(uint256 fee, uint256 maxFee);
    error InvalidPermission();
    error InvalidPaymaster(address provided, address expected);
    error InvalidSelector(bytes4 provided, bytes4 expected);
    error ExpiredPermission(uint current, uint expiredAt);

    event OperatorMutated(
        address operator,
        bytes32 oldPermissions,
        bytes32 newPermissions
    );

    function initialize(address owner) external;

    function setOperatorPermissions(
        address operator,
        bytes32 merkleRootPermissions,
        uint256 maxValue,
        uint256 maxFee
    ) external;
}
