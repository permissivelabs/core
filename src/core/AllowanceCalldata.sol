// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "Solidity-RLP/RLPReader.sol";

uint256 constant ANY = 0;
uint256 constant NE = 1;
uint256 constant EQ = 2;
uint256 constant GT = 3;
uint256 constant LT = 4;
uint256 constant AND = 5;
uint256 constant OR = 6;

library AllowanceCalldata {
    function sliceRLPItems(RLPReader.RLPItem[] memory arguments, uint256 start)
        internal
        pure
        returns (RLPReader.RLPItem[] memory newArguments)
    {
        newArguments = new RLPReader.RLPItem[](arguments.length - start);
        uint256 initialStart = start;
        for (; start < arguments.length; start++) {
            newArguments[start - initialStart] = arguments[start];
        }
    }

    function validateArguments(
        RLPReader.RLPItem[] memory allowedArguments,
        RLPReader.RLPItem[] memory arguments,
        bool isOr
    ) internal view returns (bool canPass) {
        if (allowedArguments.length == 0) return true;
        for (uint256 i = 0; i < allowedArguments.length; i++) {
            RLPReader.RLPItem[] memory prefixAndArg = RLPReader.toList(allowedArguments[i]);
            uint256 prefix = RLPReader.toUint(prefixAndArg[0]);

            if (prefix == ANY) {} else if (prefix == EQ) {
                bytes memory allowedArgument = RLPReader.toBytes(prefixAndArg[1]);
                bytes memory argument = RLPReader.toBytes(arguments[i]);
                canPass = keccak256(allowedArgument) == keccak256(argument);
            } else if (prefix == LT) {
                uint256 allowedArgument = RLPReader.toUint(prefixAndArg[1]);
                uint256 argument = RLPReader.toUint(arguments[i]);
                canPass = argument < allowedArgument;
            } else if (prefix == GT) {
                uint256 allowedArgument = RLPReader.toUint(prefixAndArg[1]);
                uint256 argument = RLPReader.toUint(arguments[i]);
                canPass = argument > allowedArgument;
            } else if (prefix == OR) {
                RLPReader.RLPItem[] memory subAllowance = RLPReader.toList(prefixAndArg[1]);
                canPass = validateArguments(subAllowance, sliceRLPItems(arguments, i), true);
                i++;
            } else if (prefix == NE) {
                bytes memory allowedArgument = RLPReader.toBytes(prefixAndArg[1]);
                bytes memory argument = RLPReader.toBytes(arguments[i]);
                canPass = keccak256(allowedArgument) != keccak256(argument);
            } else if (prefix == AND) {
                RLPReader.RLPItem[] memory subAllowance = RLPReader.toList(prefixAndArg[1]);
                canPass = validateArguments(subAllowance, sliceRLPItems(arguments, i), false);
                i++;
            } else {
                revert("Invalid calldata prefix");
            }

            if (!isOr && !canPass) break;
            if (canPass && isOr) break;
        }
        return canPass;
    }

    function isAllowedCalldata(bytes memory allowed, bytes memory data, uint256 value)
        internal
        view
        returns (bool isOk)
    {
        RLPReader.RLPItem memory RLPAllowed = RLPReader.toRlpItem(allowed);
        RLPReader.RLPItem[] memory allowedArguments = RLPReader.toList(RLPAllowed);
        RLPReader.RLPItem memory RLPData = RLPReader.toRlpItem(data);
        RLPReader.RLPItem[] memory arguments = RLPReader.toList(RLPData);
        if (allowedArguments.length != arguments.length) {
            revert("Invalid arguments length");
        }
        if (value != RLPReader.toUint(arguments[0])) {
            revert("msg.value not matching with provided value");
        }
        isOk = validateArguments(allowedArguments, arguments, false);
    }

    function RLPtoABI(bytes memory data) internal pure returns (bytes memory abiEncoded) {
        RLPReader.RLPItem memory RLPData = RLPReader.toRlpItem(data);
        RLPReader.RLPItem[] memory arguments = RLPReader.toList(RLPData);
        for (uint256 i = 1; i < arguments.length; i++) {
            abiEncoded = bytes.concat(abiEncoded, RLPReader.toBytes(arguments[i]));
        }
    }
}
