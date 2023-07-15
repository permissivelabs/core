# ISafe
[Git Source](https://github.com/permissivelabs/core/blob/d0719570d71b02a6308e94b636f8594e86ad2ce4/src/integrations/safe/ISafe.sol)


## Functions
### execTransactionFromModuleReturnData


```solidity
function execTransactionFromModuleReturnData(address to, uint256 value, bytes memory data, Operation operation)
    external
    returns (bool success, bytes memory returnData);
```

## Enums
### Operation

```solidity
enum Operation {
    Call,
    DelegateCall
}
```

