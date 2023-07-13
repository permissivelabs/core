# FeeManager
[Git Source](https://github.com/permissivelabs/core/blob/6a9a97fdcc83bd3f41e6b78ff8acd4353d9d4655/src/core/FeeManager.sol)

**Inherits:**
Ownable

**Author:**
Flydexo - @Flydex0

Permissive core contracts that determines the percent of gas fee that is collected by Permissive and collects the fees


## State Variables
### fee
100 basis point, 100 = 1%, 2000 = 20%


```solidity
uint24 public fee = 2000;
```


### initialized
*needs initialization because owner is set as the CREATE2 deployer in the constructor*


```solidity
bool initialized;
```


## Functions
### initialize

initialize - Initialization function to set the real owner, see CREATE2


```solidity
function initialize(address owner) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The future owner of the FeeManager|


### setFee

setFee - Sets the Permissive fee, only callable by the owner


```solidity
function setFee(uint24 _fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fee`|`uint24`|The new fee (100 basis point)|


### pay

Function called to pay the FeeManager

*used a function to avoid gas details in the core contracts*


```solidity
function pay() external payable;
```

## Events
### FeePaid
FeePaid - Emitted when the Permissive fee is collected


```solidity
event FeePaid(address indexed from, uint256 amount);
```

