// SPDX-License-Indetifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/core/PermissiveFactory.sol";
import "../src/core/PermissiveAccount.sol";
import "../src/core/FeeManager.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address entrypoint = vm.envAddress("ENTRYPOINT");
        bytes32 versionSalt = vm.envBytes32("VERSION_SALT");
        vm.startBroadcast(deployerPrivateKey);
        // FeeManager feeManager = new FeeManager{salt: versionSalt}();
        // feeManager.initialize(vm.envAddress("OWNER"));
        PermissiveAccount impl = new PermissiveAccount{salt: versionSalt}(
            entrypoint,
            payable(address(0x687F79f1BBC3591C541b25D3ce3A642E3c822909))
        );
        new PermissiveFactory{salt: versionSalt}(address(impl));
        vm.stopBroadcast();
    }
}
