# PermissionExecutor
[Git Source](https://github.com/permissivelabs/core/blob/6a9a97fdcc83bd3f41e6b78ff8acd4353d9d4655/src/core/PermissionExecutor.sol)

**Inherits:**
[IPermissionExecutor](/src/interfaces/IPermissionExecutor.sol/interface.IPermissionExecutor.md)

*see {IPermissionExecutor}*


## State Variables
### feeManager

```solidity
FeeManager private immutable feeManager;
```


## Functions
### constructor


```solidity
constructor(FeeManager _feeManager);
```

### execute


```solidity
function execute(
    address dest,
    uint256 value,
    bytes calldata func,
    Permission calldata permission,
    bytes32[] calldata,
    uint256 gasFee
) external;
```

