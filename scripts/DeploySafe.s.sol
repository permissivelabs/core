// SPDX-License-Indetifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/integrations/safe/SafeFactory.sol";
import "../src/core/FeeManager.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract DeploySafeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address entrypoint = vm.envAddress("ENTRYPOINT");
        address feeManager = vm.envAddress("FEE_MANAGER");
        bytes32 versionSalt = vm.envBytes32("VERSION_SALT");
        vm.startBroadcast(deployerPrivateKey);
        new SafeFactory{salt: versionSalt}(entrypoint, payable(feeManager));
        vm.stopBroadcast();
    }
}
