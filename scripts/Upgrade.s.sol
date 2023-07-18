// SPDX-License-Indetifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/core/PermissiveFactory.sol";
import "../src/core/PermissiveAccount.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address entrypoint = vm.envAddress("ENTRYPOINT");
        bytes32 versionSalt = vm.envBytes32("VERSION_SALT");
        address feeManager = vm.envAddress("FEE_MANAGER");
        vm.startBroadcast(deployerPrivateKey);
        PermissiveAccount impl = new PermissiveAccount{salt: versionSalt}(
            entrypoint,
            payable(address(feeManager))
        );
        PermissiveFactory(0x03Fc43A9124813720A14889bE92eE44A73c7b3ec).upgradeTo(
                address(impl)
            );
        vm.addr(deployerPrivateKey);
        vm.stopBroadcast();
    }
}
