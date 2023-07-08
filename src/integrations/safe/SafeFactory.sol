// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./SafeModule.sol";
import "../../interfaces/IFactory.sol";

contract SafeFactory is UpgradeableBeacon, IFactory {
    constructor(address _impl) UpgradeableBeacon(_impl) {}

    function createAccount(
        address safe,
        uint256 salt
    ) public returns (address ret) {
        address addr = getAddress(safe, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return payable(addr);
        }
        ret = payable(
            new BeaconProxy{salt: bytes32(salt)}(
                address(this),
                abi.encodeCall(SafeModule.setSafe, (safe))
            )
        );
        emit AccountCreated(safe, salt, address(ret));
    }

    function getAddress(
        address safe,
        uint256 salt
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(BeaconProxy).creationCode,
                        abi.encode(
                            address(this),
                            abi.encodeCall(SafeModule.setSafe, (safe))
                        )
                    )
                )
            );
    }
}
