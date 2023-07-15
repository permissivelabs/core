# PermissionRegistry
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/core/PermissionRegistry.sol)

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

