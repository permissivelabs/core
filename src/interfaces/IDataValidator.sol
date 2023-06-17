// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

interface IDataValidator {
    function isValidData(address target, bytes calldata data) external view returns (bool);
}
