# SafeModule
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/integrations/safe/SafeModule.sol)


## State Variables
### safe

```solidity
ISafe public safe;
```


### entryPoint

```solidity
IEntryPoint immutable entryPoint;
```


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
constructor(IEntryPoint _entryPoint, PermissionVerifier _verifier, PermissionExecutor _executor);
```

### setSafe


```solidity
function setSafe(address _safe) external;
```

### validateUserOp


```solidity
function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external
    returns (uint256 validationData);
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

### _requireFromEntryPointOrOwner


```solidity
function _requireFromEntryPointOrOwner() internal view;
```

### _payPrefund


```solidity
function _payPrefund(uint256 missingAccountFunds) internal;
```

### receive


```solidity
receive() external payable;
```

### _onlySafe


```solidity
function _onlySafe() internal view;
```

## Events
### OperatorMutated

```solidity
event OperatorMutated(address indexed operator, bytes32 indexed oldPermissions, bytes32 indexed newPermissions);
```

### PermissionVerified

```solidity
event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);
```

### PermissionUsed

```solidity
event PermissionUsed(
    bytes32 indexed permHash, address dest, uint256 value, bytes func, Permission permission, uint256 gasFee
);
```

### NewSafe

```solidity
event NewSafe(address safe);
```

