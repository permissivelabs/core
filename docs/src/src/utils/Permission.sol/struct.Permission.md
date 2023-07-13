# Permission
[Git Source](https://github.com/permissivelabs/core/blob/6a9a97fdcc83bd3f41e6b78ff8acd4353d9d4655/src/utils/Permission.sol)

**Author:**
Flydexo - @Flydex0

A permission is made for a specific function of a specific contract

*1 operator = 1 permission set*

*1 permission set = infinite permissions*


```solidity
struct Permission {
    address operator;
    address to;
    bytes4 selector;
    bytes allowed_arguments;
    address paymaster;
    uint48 validUntil;
    uint48 validAfter;
    uint256 maxUsage;
    address dataValidator;
}
```
