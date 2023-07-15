# IPermissionVerifier
[Git Source](https://github.com/permissivelabs/core/blob/ffc718211b4e17bab264d162220cde08c464a11c/src/interfaces/IPermissionVerifier.sol)

**Author:**
Flydexo - @Flydex0

Contract only callable with delegatecall by the account itself or it's module or plugin


## Functions
### verify

verify - Function that make all the Permissive related checks on the userOperation.

*For validationData specs see see https://eips.ethereum.org/EIPS/eip-4337#definitions*


```solidity
function verify(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external
    returns (uint256 validationData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userOp`|`UserOperation`|The userOperation|
|`userOpHash`|`bytes32`|The userOperation hash|
|`missingAccountFunds`|`uint256`|The funds the sender needs to pay to the EntryPoint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validationData`|`uint256`|The validation data that signals are valid / invalid signature and the timespan of the permission|


### computeGasFee

computeGasFee - Function called to compute the gasFee of the userOperation depending on all the gas parameters of the operation.

*Use this function to determine the fee in the execute function*


```solidity
function computeGasFee(UserOperation memory userOp) external pure returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userOp`|`UserOperation`|The userOperation|


## Events
### PermissionVerified
PermissionVerified - Emitted when a permission is successfully verified


```solidity
event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);
```

