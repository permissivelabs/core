// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissionRegistry.sol";
import "./utils/Signature.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RegistryTest is Test {
    PermissionRegistry registry;
    SigUtils sigUtils;

    function setUp() public {
        registry = new PermissionRegistry();
        sigUtils = new SigUtils(
            DomainSeparatorUtils.buildDomainSeparator(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Permisive PermissionRegistry")),
                keccak256(bytes("0.0.46")),
                address(registry)
            )
        );
    }

    function testOperatorPermissions(PermissionSet calldata permSet) public {
        registry.setOperatorPermissions(permSet);
        assert(
            registry.operatorPermissions(address(this), permSet.operator) ==
                permSet.merkleRootPermissions
        );
    }

    function testPermusage(uint256 permUsage, bytes32 permHash) public {
        registry.setRemainingPermUsage(permHash, permUsage);
        assert(
            registry.remainingPermUsage(address(this), permHash) == permUsage
        );
    }
}
