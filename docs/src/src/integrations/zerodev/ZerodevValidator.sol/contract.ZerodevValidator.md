# ZerodevValidator
[Git Source](https://github.com/permissivelabs/core/blob/ffc718211b4e17bab264d162220cde08c464a11c/src/integrations/zerodev/ZerodevValidator.sol)

**Inherits:**
IKernelValidator


## State Variables
### permissionVerifier

```solidity
PermissionVerifier immutable permissionVerifier;
```


## Functions
### constructor


```solidity
constructor(PermissionVerifier verifier);
```

### enable


```solidity
function enable(bytes calldata) external override;
```

### disable


```solidity
function disable(bytes calldata) external pure override;
```

### validateUserOp


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external
    override
    returns (uint256 validationData);
```

### validateSignature


```solidity
function validateSignature(bytes32 hash, bytes calldata signature) external view override returns (uint256);
```

