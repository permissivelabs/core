// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/integrations/safe/new-spec/SafePlugin.sol";

contract DeployCore is Script {
    function run() public {
        bytes32 salt = vm.envBytes32("VERSION_SALT");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        SafePlugin safeImpl = new SafePlugin{salt: salt}(
            vm.envAddress("ENTRYPOINT"),
            0xCa97548f9C9E2f5031d569B76BF07a525e91E423,
            0x4692af28A8a315909bEeEa6EB994EF3598Fe84dC,
            0x67cedc3C2A558F1C7DAE639C97cd88C6770Bd9B6
        );
        ERC1967Proxy safe = new ERC1967Proxy{salt: salt}(
            address(safeImpl),
            hex""
        );
        vm.stopBroadcast();
        console.log("SafePlugin impl:", address(safeImpl));
        console.log("SafePlugin:", address(safe));
    }
}
