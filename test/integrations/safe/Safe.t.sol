// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "safe/SafeL2.sol";
import "../../../src/integrations/safe/SafeModule.sol";
import "../../../src/core/PermissionExecutor.sol";
import "../../../src/core/PermissionVerifier.sol";
import "../../../src/core/PermissionRegistry.sol";
import "../../../src/core/FeeManager.sol";
import "account-abstraction/core/EntryPoint.sol";

contract SafeTest is Test {
    SafeL2 safe;
    SafeModule permissive;
    EntryPoint entryPoint;
    PermissionVerifier verifier;
    PermissionExecutor executor;
    PermissionRegistry registry;
    FeeManager feeManager;

    function setUp() public {
        safe = new SafeL2();
        entryPoint = new EntryPoint();
        feeManager = new FeeManager();
        registry = new PermissionRegistry();
        verifier = new PermissionVerifier(registry);
        executor = new PermissionExecutor(feeManager);
        permissive = new SafeModule(entryPoint, verifier, executor);
        safe.enableModule(address(permissive));
    }
}
