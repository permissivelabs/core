# ISafe
[Git Source](https://github.com/permissivelabs/core/blob/ffc718211b4e17bab264d162220cde08c464a11c/src/integrations/safe/ISafe.sol)


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

