// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "solidity-rlp/contracts/RLPReader.sol";

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
        RLPReader.RLPItem[] memory arguments
    ) internal pure {
        if (allowedArguments.length == 0) revert();
        for (uint i = 0; i < allowedArguments.length; i++) {
            RLPReader.RLPItem[] memory prefixAndArg = RLPReader.toList(
                allowedArguments[i]
            );
            uint prefix = RLPReader.toUint(prefixAndArg[0]);

            if (prefix == 0) {} else if (prefix == 1) {
                bytes memory allowedArgument = RLPReader.toBytes(
                    prefixAndArg[1]
                );
                bytes memory argument = RLPReader.toBytes(arguments[i]);
                assert(keccak256(allowedArgument) == keccak256(argument));
            } else if (prefix == 2) {
                uint allowedArgument = RLPReader.toUint(prefixAndArg[1]);
                uint argument = RLPReader.toUint(arguments[i]);
                assert(allowedArgument < argument);
            } else if (prefix == 3) {
                uint allowedArgument = RLPReader.toUint(prefixAndArg[1]);
                uint argument = RLPReader.toUint(arguments[i]);
                assert(allowedArgument > argument);
            } else if (prefix == 4) {
                RLPReader.RLPItem[] memory subAllowance = RLPReader.toList(
                    prefixAndArg[1]
                );
                validateArguments(subAllowance, sliceRLPItems(arguments, i));
                i++;
            } else {
                revert();
            }
        }
    }

    function isAllowedCalldata(
        bytes calldata allowed,
        bytes calldata data
    ) external pure returns (bool) {
        RLPReader.RLPItem memory RLPAllowed = RLPReader.toRlpItem(allowed);
        RLPReader.RLPItem[] memory allowedArguments = RLPReader.toList(
            RLPAllowed
        );
        RLPReader.RLPItem memory RLPData = RLPReader.toRlpItem(data);
        RLPReader.RLPItem[] memory arguments = RLPReader.toList(RLPData);
        if (allowedArguments.length != arguments.length) revert();
        validateArguments(allowedArguments, arguments);
        return true;
    }
}
