# Safe4337Module
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/integrations/safe/Safe4337.sol)

**Inherits:**
SafeStorage


## State Variables
### myAddress

```solidity
address immutable myAddress;
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


### SENTINEL_MODULES

```solidity
address internal constant SENTINEL_MODULES = address(0x1);
```


## Functions
### constructor


```solidity
constructor(IEntryPoint _entryPoint, PermissionVerifier verifier, PermissionExecutor executor);
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

### enableMyself


```solidity
function enableMyself() public;
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

