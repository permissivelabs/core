// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/script.sol";
import "../../src/core/FeeManager.sol";
import "../../src/core/PermissionRegistry.sol";
import "../../src/core/PermissionExecutor.sol";
import "../../src/core/PermissionVerifier.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCore is Script {
    function run() public {
        bytes32 salt = vm.envBytes32("VERSION_SALT");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeeManager feeManagerImpl = new FeeManager{salt: salt}();
        ERC1967Proxy feeManager = new ERC1967Proxy{salt: salt}(
            address(feeManagerImpl),
            abi.encodeWithSelector(
                FeeManager.initialize.selector,
                vm.addr(privateKey)
            )
        );
        PermissionRegistry registryImpl = new PermissionRegistry{salt: salt}();
        ERC1967Proxy registry = new ERC1967Proxy{salt: salt}(
            address(registryImpl),
            hex""
        );
        PermissionExecutor executorImpl = new PermissionExecutor{salt: salt}(
            FeeManager(address(feeManager))
        );
        ERC1967Proxy executor = new ERC1967Proxy{salt: salt}(
            address(executorImpl),
            hex""
        );
        PermissionVerifier verifierImpl = new PermissionVerifier{salt: salt}(
            PermissionRegistry(address(registry))
        );
        ERC1967Proxy verifier = new ERC1967Proxy{salt: salt}(
            address(verifierImpl),
            hex""
        );
        vm.stopBroadcast();
        console.log("FeeManager impl:", address(feeManagerImpl));
        console.log("PermissionRegistry impl:", address(registryImpl));
        console.log("PermissionExecutor impl:", address(executorImpl));
        console.log("PermissionVerifier impl:", address(verifierImpl));
        console.log("FeeManager:", address(feeManager));
        console.log("PermissionRegistry:", address(registry));
        console.log("PermissionExecutor:", address(executor));
        console.log("PermissionVerifier:", address(verifier));
    }
}
