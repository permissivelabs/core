// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "Solidity-RLP/RLPReader.sol";

uint constant ANY = 0;
uint constant NE = 1;
uint constant EQ = 2;
uint constant GT = 3;
uint constant LT = 4;
uint constant AND = 5;
uint constant OR = 6;

library AllowanceCalldata {
    function sliceRLPItems(
        RLPReader.RLPItem[] memory arguments,
        uint start
    ) internal pure returns (RLPReader.RLPItem[] memory newArguments) {
        newArguments = new RLPReader.RLPItem[](arguments.length - start);
        uint initialStart = start;
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
        for (uint i = 0; i < allowedArguments.length; i++) {
            RLPReader.RLPItem[] memory prefixAndArg = RLPReader.toList(
                allowedArguments[i]
            );
            uint prefix = RLPReader.toUint(prefixAndArg[0]);

            if (prefix == ANY) {} else if (prefix == EQ) {
                bytes memory allowedArgument = RLPReader.toBytes(
                    prefixAndArg[1]
                );
                bytes memory argument = RLPReader.toBytes(arguments[i]);
                canPass = keccak256(allowedArgument) == keccak256(argument);
            } else if (prefix == LT) {
                uint allowedArgument = RLPReader.toUint(prefixAndArg[1]);
                uint argument = RLPReader.toUint(arguments[i]);
                canPass = argument < allowedArgument;
            } else if (prefix == GT) {
                uint allowedArgument = RLPReader.toUint(prefixAndArg[1]);
                uint argument = RLPReader.toUint(arguments[i]);
                canPass = argument > allowedArgument;
            } else if (prefix == OR) {
                RLPReader.RLPItem[] memory subAllowance = RLPReader.toList(
                    prefixAndArg[1]
                );
                canPass = validateArguments(
                    subAllowance,
                    sliceRLPItems(arguments, i),
                    true
                );
                i++;
            } else if (prefix == NE) {
                bytes memory allowedArgument = RLPReader.toBytes(
                    prefixAndArg[1]
                );
                bytes memory argument = RLPReader.toBytes(arguments[i]);
                canPass = keccak256(allowedArgument) != keccak256(argument);
            } else if (prefix == AND) {
                RLPReader.RLPItem[] memory subAllowance = RLPReader.toList(
                    prefixAndArg[1]
                );
                canPass = validateArguments(
                    subAllowance,
                    sliceRLPItems(arguments, i),
                    false
                );
                i++;
            } else {
                revert();
            }

            if (!isOr && !canPass) break;
            if (canPass && isOr) break;
        }
        return canPass;
    }

    function isAllowedCalldata(
        bytes calldata allowed,
        bytes calldata data
    ) external view returns (bool isOk) {
        RLPReader.RLPItem memory RLPAllowed = RLPReader.toRlpItem(allowed);
        RLPReader.RLPItem[] memory allowedArguments = RLPReader.toList(
            RLPAllowed
        );
        RLPReader.RLPItem memory RLPData = RLPReader.toRlpItem(data);
        RLPReader.RLPItem[] memory arguments = RLPReader.toList(RLPData);
        if (allowedArguments.length != arguments.length) revert();
        isOk = validateArguments(allowedArguments, arguments, false);
    }

    function RLPtoABI(
        bytes calldata data
    ) external pure returns (bytes memory abiEncoded) {
        RLPReader.RLPItem memory RLPData = RLPReader.toRlpItem(data);
        RLPReader.RLPItem[] memory arguments = RLPReader.toList(RLPData);
        for (uint256 i = 0; i < arguments.length; i++) {
            abiEncoded = bytes.concat(
                abiEncoded,
                RLPReader.toBytes(arguments[i])
            );
        }
    }
}
