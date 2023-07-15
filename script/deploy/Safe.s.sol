// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/script.sol";
import "../../src/core/PermissionVerifier.sol";
import "../../src/core/PermissionExecutor.sol";
import "../../src/integrations/safe/SafeModule.sol";
import "../../src/integrations/safe/Safe4337.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCore is Script {
    function run() public {
        bytes32 salt = vm.envBytes32("VERSION_SALT");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        SafeModule safeImpl = new SafeModule{salt: salt}(
            IEntryPoint(vm.envAddress("ENTRYPOINT")),
            PermissionVerifier(
                address(0x141A637e4516A7B03b6B7530d6498aC9A6986028)
            ),
            PermissionExecutor(
                address(0x878f23FD2489E5B0e0D28EA475852c09183FfC1A)
            )
        );
        ERC1967Proxy safe = new ERC1967Proxy{salt: salt}(
            address(safeImpl),
            hex""
        );
        Safe4337Module safe4337Impl = new Safe4337Module{salt: salt}(
            IEntryPoint(vm.envAddress("ENTRYPOINT")),
            PermissionVerifier(
                address(0x141A637e4516A7B03b6B7530d6498aC9A6986028)
            ),
            PermissionExecutor(
                address(0x878f23FD2489E5B0e0D28EA475852c09183FfC1A)
            )
        );
        ERC1967Proxy safe4337 = new ERC1967Proxy{salt: salt}(
            address(safe4337Impl),
            hex""
        );
        vm.stopBroadcast();
        console.log("SafeModule impl:", address(safeImpl));
        console.log("SafeModule:", address(safe));
        console.log("Safe4337Module impl:", address(safe4337Impl));
        console.log("Safe4337Module:", address(safe4337));
    }
}
