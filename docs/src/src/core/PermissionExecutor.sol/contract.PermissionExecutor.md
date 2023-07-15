# PermissionExecutor
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/core/PermissionExecutor.sol)

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

