# ISafe
[Git Source](https://github.com/permissivelabs/core/blob/6a9a97fdcc83bd3f41e6b78ff8acd4353d9d4655/src/integrations/safe/ISafe.sol)


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

