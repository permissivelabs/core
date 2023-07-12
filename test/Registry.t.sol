// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissionRegistry.sol";
import "./utils/Signature.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RegistryTest is Test {
    PermissionRegistry registry;

    function setUp() public {
        registry = new PermissionRegistry();
    }

    function testOperatorPermissions(address operator, bytes32 root) public {
        registry.setOperatorPermissions(operator, root);
        assert(registry.operatorPermissions(address(this), operator) == root);
    }

    function testPermusage(uint256 permUsage, bytes32 permHash) public {
        registry.setRemainingPermUsage(permHash, permUsage);
        assert(
            registry.remainingPermUsage(address(this), permHash) == permUsage
        );
    }
}
