# IDataValidator
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/interfaces/IDataValidator.sol)

**Author:**
Flydexo - @Flydex0

This can be used for example to track the amount of granted ERC20 spent / swapped, etc...

*The DataValidator contract must respect ERC-4337 storage rules. That means the only storage accessible must have the userOp.sender as key.*

*see https://eips.ethereum.org/EIPS/eip-4337#simulation*


## Functions
### isValidData

isValidData is called in the validateUserOp function of the PermissionVerifier contract

*userOp is formatted as integration agnostic, that means that if the SA (eg. Zerodev) requires a special field in the signature to determine which plugin to use, it is removed. Then the PermissionVerifier is called.*


```solidity
function isValidData(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external
    returns (bool success);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userOp`|`UserOperation`|The userOp|
|`userOpHash`|`bytes32`|The userOp hash|
|`missingAccountFunds`|`uint256`|The funds the sender needs to pay to the EntryPoint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|Can revert to add additional logs and returns true if the userOp is considered valid|


