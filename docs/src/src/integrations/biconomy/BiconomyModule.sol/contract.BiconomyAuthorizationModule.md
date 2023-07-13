# BiconomyAuthorizationModule
[Git Source](https://github.com/permissivelabs/core/blob/6a9a97fdcc83bd3f41e6b78ff8acd4353d9d4655/src/integrations/biconomy/BiconomyModule.sol)

**Inherits:**
BaseAuthorizationModule


## State Variables
### permissionVerifier

```solidity
PermissionVerifier immutable permissionVerifier;
```


### permissionExecutor

```solidity
PermissionExecutor immutable permissionExecutor;
```


## Functions
### constructor


```solidity
constructor(PermissionVerifier _verifier, PermissionExecutor _executor);
```

### validateUserOp


```solidity
function validateUserOp(UserOperation memory userOp, bytes32 userOpHash) external returns (uint256 validationData);
```

### execute


```solidity
function execute(
    address dest,
    uint256 value,
    bytes memory func,
    Permission calldata permission,
    bytes32[] calldata proof,
    uint256 gasFee
) external;
```

### isValidSignature


```solidity
function isValidSignature(bytes32 _dataHash, bytes memory _signature) public view override returns (bytes4);
```

