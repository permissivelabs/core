# ISafe
[Git Source](https://github.com/permissivelabs/core/blob/fa33ef18b6b5de6eccb85fa5ba3f8e660923b0ae/src/integrations/safe/ISafe.sol)


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

