// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/script.sol";
import "../../src/core/PermissionVerifier.sol";
import "../../src/integrations/6900/OperationValidator.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCore is Script {
    function run() public {
        bytes32 salt = vm.envBytes32("VERSION_SALT");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        OperationValidator ercImpl = new OperationValidator{salt: salt}(
            PermissionVerifier(
                address(0x141A637e4516A7B03b6B7530d6498aC9A6986028)
            )
        );
        ERC1967Proxy erc = new ERC1967Proxy{salt: salt}(
            address(ercImpl),
            hex""
        );
        vm.stopBroadcast();
        console.log("OperationValidator impl:", address(ercImpl));
        console.log("OperationValidator:", address(erc));
    }
}
