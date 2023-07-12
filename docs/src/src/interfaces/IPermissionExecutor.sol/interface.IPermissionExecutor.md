# IPermissionExecutor
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/interfaces/IPermissionExecutor.sol)

**Author:**
Flydexo - @Flydex0

Emits events for the Indexer


## Functions
### execute

Execute a permissioned userOperation


```solidity
function execute(
    address dest,
    uint256 value,
    bytes calldata func,
    Permission calldata permission,
    bytes32[] calldata proof,
    uint256 gasFee
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dest`|`address`|The called contract|
|`value`|`uint256`|The msg.value|
|`func`|`bytes`|The AllowanceCalldata used to call the contract|
|`permission`|`Permission`|The permission object|
|`proof`|`bytes32[]`||
|`gasFee`|`uint256`|The fee for the userOperation (used to compute the Permissive fee)|


## Events
### PermissionUsed
PermissionUsed - When a permissioned userOperation passed with success


```solidity
event PermissionUsed(
    bytes32 indexed permHash, address dest, uint256 value, bytes func, Permission permission, uint256 gasFee
);
```

