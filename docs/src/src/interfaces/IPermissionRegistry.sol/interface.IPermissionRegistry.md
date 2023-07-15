# IPermissionRegistry
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/interfaces/IPermissionRegistry.sol)

**Author:**
Flydexo - @Flydex0

PermissionRegistry stores the permissions of an operator on an account and the remaining usages of a permission on an account.


## Functions
### operatorPermissions

operatorPermissions - Getter for the granted permissions of an operator on an account


```solidity
function operatorPermissions(address sender, address operator) external view returns (bytes32 permHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The account address|
|`operator`|`address`|The operator address|


### remainingPermUsage

remainingPermUsage - Getter for the remaining usage of a permission on an account (usage + 1)


```solidity
function remainingPermUsage(address sender, bytes32 permHash) external view returns (uint256 remainingUsage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The account address|
|`permHash`|`bytes32`|The permission hash|


### setOperatorPermissions

setOperatorPermissions - Setter for the granted permissions of an operator on an account. Can only be called by the account modifying it's own operator permissions.


```solidity
function setOperatorPermissions(address operator, bytes32 root) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|The operator address|
|`root`|`bytes32`|The permissions merkle root|


### setRemainingPermUsage

setRemainingPermUsage - Setter for the remaining usage of a permission on an account. Can only be called by the account modifying it's own usage


```solidity
function setRemainingPermUsage(bytes32 permHash, uint256 remainingUsage) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permHash`|`bytes32`|The permission hash|
|`remainingUsage`|`uint256`|The permission remaining usage (usage + 1)|


## Events
### OperatorMutated
OperatorMutated - Emitted when the granted permisssions for an operator on an account change


```solidity
event OperatorMutated(address indexed operator, bytes32 indexed oldPermissions, bytes32 indexed newPermissions);
```

