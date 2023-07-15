# PermissionExecutor
[Git Source](https://github.com/permissivelabs/core/blob/ffc718211b4e17bab264d162220cde08c464a11c/src/core/PermissionExecutor.sol)

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

