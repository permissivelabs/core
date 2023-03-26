// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AllowanceCalldata.sol";

contract AllowanceCalldataTest is Test {
    AllowanceCalldata public verifier;
    bytes allowanceData =
        hex"f845d60194690b9a9e9aa1c9db991c7721a92d351db4fac990c902872386f26fc0ffffcc04cac903872386f26fc0ffffd60194690b9a9e9aa1c9db991c7721a92d351db4fac990";
    bytes callData =
        hex"f794690b9a9e9aa1c9db991c7721a92d351db4fac990872386f26fc10000842386f26f94690b9a9e9aa1c9db991c7721a92d351db4fac990";

    function setUp() public {
        verifier = new AllowanceCalldata();
    }

    function hasNoZeroPrefix(bytes calldata data) internal pure returns (bool) {
        RLPReader.RLPItem memory RLPAllowed = RLPReader.toRlpItem(data);
        if (!RLPReader.isList(RLPAllowed)) return false;
        RLPReader.RLPItem[] memory allowedArguments = RLPReader.toList(
            RLPAllowed
        );
        for (uint i = 0; i < allowedArguments.length; i++) {
            RLPReader.RLPItem[] memory prefixAndArg = RLPReader.toList(
                allowedArguments[i]
            );
            uint prefix = RLPReader.toUint(prefixAndArg[0]);
            if (prefix == 0) return false;
        }
        return true;
    }

    function testShouldFailBecauseUnauthorizedData(bytes calldata data) public {
        vm.assume(keccak256(data) != keccak256(callData));
        vm.expectRevert();
        verifier.isAllowedCalldata(allowanceData, data);
    }

    function testShouldFailBecauseUnauthorizedAllowanceData(
        bytes calldata data
    ) public {
        vm.expectRevert();
        verifier.isAllowedCalldata(data, callData);
    }

    function testValidCall() public view {
        verifier.isAllowedCalldata(allowanceData, callData);
    }
}
