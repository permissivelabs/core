# PermissionRegistry
[Git Source](https://github.com/permissivelabs/core/blob/ffc718211b4e17bab264d162220cde08c464a11c/src/core/PermissionRegistry.sol)

**Inherits:**
[IPermissionRegistry](/src/interfaces/IPermissionRegistry.sol/interface.IPermissionRegistry.md)

*see {IPermissionRegistry}*


## State Variables
### operatorPermissions

```solidity
mapping(address sender => mapping(address operator => bytes32 permHash)) public operatorPermissions;
```


### remainingPermUsage

```solidity
mapping(address sender => mapping(bytes32 permHash => uint256 remainingUsage)) public remainingPermUsage;
```


## Functions
### constructor


```solidity
constructor();
```

### setRemainingPermUsage


```solidity
function setRemainingPermUsage(bytes32 permHash, uint256 remainingUsage) external;
```

### setOperatorPermissions


```solidity
function setOperatorPermissions(address operator, bytes32 root) external;
```

