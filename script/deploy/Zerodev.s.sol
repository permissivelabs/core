// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/script.sol";
import "../../src/core/PermissionVerifier.sol";
import "../../src/integrations/zerodev/ZerodevValidator.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCore is Script {
    function run() public {
        bytes32 salt = vm.envBytes32("VERSION_SALT");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        ZerodevValidator zerodevImpl = new ZerodevValidator{salt: salt}(
            PermissionVerifier(
                address(0xCa97548f9C9E2f5031d569B76BF07a525e91E423)
            )
        );
        ERC1967Proxy zerodev = new ERC1967Proxy{salt: salt}(
            address(zerodevImpl),
            hex""
        );
        vm.stopBroadcast();
        console.log("ZerodevValidator impl:", address(zerodevImpl));
        console.log("ZerodevValidator:", address(zerodev));
    }
}