# OperationValidator
[Git Source](https://github.com/permissivelabs/core/blob/ffc718211b4e17bab264d162220cde08c464a11c/src/integrations/6900/OperationValidator.sol)


## State Variables
### permissionVerifier

```solidity
PermissionVerifier immutable permissionVerifier;
```


## Functions
### constructor


```solidity
constructor(PermissionVerifier _verifier);
```

### validateUserOp


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash) external returns (uint256 validationData);
```

