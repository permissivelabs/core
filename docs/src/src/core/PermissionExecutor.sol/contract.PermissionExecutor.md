# PermissionExecutor
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/core/PermissionExecutor.sol)

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

