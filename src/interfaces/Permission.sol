// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

struct DataValidation {
    // address of your IValidator
    address validator;
    // address of the contract to call
    address target;
    // address of the calldata sent to the contract
    bytes data;
}

library PermissionLib {
    struct Permission {
        // the operator
        address operator;
        // the address allowed to interact with
        address to;
        // the function selector
        bytes4 selector;
        // specific arguments that are allowed for this permisison (see readme), the first one is the value
        bytes allowed_arguments;
        // the paymaster if set will pay the transactions
        address paymaster;
        // the timestamp when the permission isn't valid anymore
        // @dev can be 0 to express infinite
        uint48 validUntil;
        // the timestamp - 1 when the permission becomes valid
        uint48 validAfter;
        // the max number of times + 1 this permision can be used, 0 = infinite
        uint256 maxUsage;
        // validate on-chain data
        DataValidation dataValidation;
    }

    function hash(Permission memory permission) internal pure returns (bytes32 permHash) {
        permHash = keccak256(abi.encode(permission));
    }
}
