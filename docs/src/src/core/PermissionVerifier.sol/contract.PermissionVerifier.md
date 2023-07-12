# PermissionVerifier
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/core/PermissionVerifier.sol)

**Inherits:**
[IPermissionVerifier](/src/interfaces/IPermissionVerifier.sol/interface.IPermissionVerifier.md)

*see {IPermissionVerifier}*


## State Variables
### permissionRegistry

```solidity
PermissionRegistry immutable permissionRegistry;
```


## Functions
### constructor


```solidity
constructor(PermissionRegistry registry);
```

### verify


```solidity
function verify(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external
    returns (uint256 validationData);
```

### computeGasFee


```solidity
function computeGasFee(UserOperation memory userOp) public pure returns (uint256 fee);
```

### _validateFee


```solidity
function _validateFee(UserOperation calldata userOp, uint256 providedFee) internal pure;
```

### _validationData


```solidity
function _validationData(UserOperation calldata userOp, bytes32 userOpHash, Permission memory permission)
    internal
    view
    returns (uint256 validationData);
```

### _validateData


```solidity
function _validateData(
    UserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds,
    Permission memory permission
) internal;
```

### _validatePermission


```solidity
function _validatePermission(
    address to,
    uint256 value,
    bytes memory callData,
    UserOperation calldata userOp,
    Permission memory permission,
    bytes32 permHash
) internal;
```

### _validateMerklePermission


```solidity
function _validateMerklePermission(Permission memory permission, bytes32[] memory proof, bytes32 permHash)
    internal
    view;
```

