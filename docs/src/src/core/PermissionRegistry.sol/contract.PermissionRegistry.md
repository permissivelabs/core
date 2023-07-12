# PermissionRegistry
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/core/PermissionRegistry.sol)

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

