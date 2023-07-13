# AllowanceCalldata
[Git Source](https://github.com/permissivelabs/core/blob/6a9a97fdcc83bd3f41e6b78ff8acd4353d9d4655/src/utils/AllowanceCalldata.sol)

**Author:**
Flydexo - @Flydex0

Library in charge of verifying that the calldata is valid corresponding the the allowed calldata conditions.


## Functions
### isAllowedCalldata

isAllowedCalldata - checks the calldata is valid corresponding the the allowed calldata conditions.

*To check the msg.value field, the first arg of data must be equal to msg.value and the first arg of allowed calldata must set rules for the value*


```solidity
function isAllowedCalldata(bytes memory allowed, bytes memory data, uint256 value) internal view returns (bool isOk);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`allowed`|`bytes`|The RLP encoded Allowed calldata|
|`data`|`bytes`|The RLP encodedx calldata|
|`value`|`uint256`|The msg.value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isOk`|`bool`|In case of success returns true, otherwise fails or reverts|


### RLPtoABI

RLPToABI - Transform the RLP encoded calldata into ABI

*the RLP calldata must already be ABI compatible when all arguments are concatenated*

*If you have n arguments to verify (including value)*

*You need to have n arguments in the RLP calldata*

*And when concatenated, the arguments must be ABI compatible*

*So if you have 1 argument to check (ignore value for the example)*

*it must be RLP.encode([abi.encode(argument)])*


```solidity
function RLPtoABI(bytes memory data) internal pure returns (bytes memory abiEncoded);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|the RLP encoded calldata|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`abiEncoded`|`bytes`|The result ABI encoded, is valid calldata|


### _validateArguments

_validateArguments - Core function of the AllowanceCalldata library, checks if arguments respect the allowedArguments conditions

*isOr is used to do the minimum checks*

*in case of AND = a single false result breaks*

*in case of OR = a single true result breaks*


```solidity
function _validateArguments(
    RLPReader.RLPItem[] memory allowedArguments,
    RLPReader.RLPItem[] memory arguments,
    bool isOr
) internal view returns (bool canPass);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`allowedArguments`|`RLPReader.RLPItem[]`|The allowed arguments|
|`arguments`|`RLPReader.RLPItem[]`|The arguments|
|`isOr`|`bool`|Is the current loop in a or condition|


### _unsafe_inc

optimized incrementation


```solidity
function _unsafe_inc(uint256 i) private pure returns (uint256);
```

### _fillArray

_fillArray - Creates a new array filled with the same item


```solidity
function _fillArray(RLPReader.RLPItem[] memory arguments, uint256 index, uint256 length)
    internal
    pure
    returns (RLPReader.RLPItem[] memory newArguments);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`arguments`|`RLPReader.RLPItem[]`|Array of arguments to take the item from|
|`index`|`uint256`|The index of the item to fill with|
|`length`|`uint256`|The length of the new filled array|


