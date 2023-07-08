// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

interface IFactory {
    event AccountCreated(
        address indexed safe,
        uint256 indexed salt,
        address indexed account
    );

    function createAccount(
        address safe,
        uint256 salt
    ) external returns (address ret);

    function getAddress(
        address safe,
        uint256 salt
    ) external view returns (address);
}
