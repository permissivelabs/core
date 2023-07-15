# OperationValidator
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/integrations/6900/OperationValidator.sol)


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

