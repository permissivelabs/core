// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./PermissiveAccount.sol";
import "./FeeManager.sol";

contract PermissiveFactory is UpgradeableBeacon, Initializable {
    event AccountCreated(
        address indexed owner,
        uint256 indexed salt,
        address indexed account
    );

    constructor(address _impl) UpgradeableBeacon(_impl) {}

    function initialize(address owner) external initializer {
        _transferOwnership(owner);
    }

    function createAccount(
        address owner,
        uint256 salt
    ) public returns (PermissiveAccount ret) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return PermissiveAccount(payable(addr));
        }
        ret = PermissiveAccount(
            payable(
                new BeaconProxy{salt: bytes32(salt)}(
                    address(this),
                    abi.encodeCall(PermissiveAccount.initialize, (owner))
                )
            )
        );
        emit AccountCreated(owner, salt, address(ret));
    }

    function getAddress(
        address owner,
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
                            abi.encodeCall(
                                PermissiveAccount.initialize,
                                (owner)
                            )
                        )
                    )
                )
            );
    }
}
