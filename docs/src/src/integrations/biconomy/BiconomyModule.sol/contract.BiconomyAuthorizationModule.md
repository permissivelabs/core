# BiconomyAuthorizationModule
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/integrations/biconomy/BiconomyModule.sol)

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

