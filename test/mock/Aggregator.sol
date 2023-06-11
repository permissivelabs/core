// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

import "account-abstraction/interfaces/IAggregator.sol";
import "forge-std/console.sol";

contract Aggregator is IAggregator {
    mapping(bytes32 signatureHash => bool isSigned) private signatures;

    function validateSignatures(UserOperation[] calldata userOps, bytes calldata) external view override {
        console.log(667);
        for (uint256 i = 0; i < userOps.length; i++) {
            require(signatures[keccak256(userOps[i].signature)], "Signer did not sign");
        }
    }

    function validateUserOpSignature(UserOperation calldata userOp)
        external
        view
        override
        returns (bytes memory sigForUserOp)
    {
        console.log(668);
        require(signatures[keccak256(userOp.signature)], "Signer did not sign");
        return userOp.signature;
    }

    function aggregateSignatures(UserOperation[] calldata userOps)
        external
        view
        override
        returns (bytes memory aggregatedSignature)
    {}

    function sign(bytes calldata data) external {
        signatures[keccak256(data)] = true;
    }
}
