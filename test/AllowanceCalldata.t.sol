// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/AllowanceCalldata.sol";

contract AllowanceCalldataTest is Test {
    bytes allowanceData =
        hex"f8b9f86c06f869e202a0000000000000000000000000429952c8d27f515011d623dfc9038152af52c5a8e202a0000000000000000000000000c1b634853cb333d3ad8663715b08f41a3aec47cce202a00000000000000000000000006887246668a3b87f54deb3b94ba47a6f63f32985f84905f846e203a00000000000000000000000000000000000000000000000008ac7230489e80000e204a0000000000000000000000000000000000000000000000002b5e3af16b1880000";
    bytes callData =
        hex"f842a0000000000000000000000000429952c8d27f515011d623dfc9038152af52c5a8a00000000000000000000000000000000000000000000000056bc75e2d63100000";

    function hasNoZeroPrefix(bytes calldata data) internal pure returns (bool) {
        RLPReader.RLPItem memory RLPAllowed = RLPReader.toRlpItem(data);
        if (!RLPReader.isList(RLPAllowed)) return false;
        RLPReader.RLPItem[] memory allowedArguments = RLPReader.toList(RLPAllowed);
        for (uint256 i = 0; i < allowedArguments.length; i++) {
            RLPReader.RLPItem[] memory prefixAndArg = RLPReader.toList(allowedArguments[i]);
            uint256 prefix = RLPReader.toUint(prefixAndArg[0]);
            if (prefix == 0) return false;
        }
        return true;
    }

    function testShouldFailBecauseUnauthorizedData(bytes calldata data) public {
        vm.assume(keccak256(data) != keccak256(callData));
        vm.expectRevert();
        AllowanceCalldata.isAllowedCalldata(allowanceData, data);
    }

    function testShouldFailBecauseUnauthorizedAllowanceData(bytes calldata data) public {
        vm.expectRevert();
        AllowanceCalldata.isAllowedCalldata(data, callData);
    }

    function testValidCall() public view {
        assert(AllowanceCalldata.isAllowedCalldata(allowanceData, callData) == true);
    }
}
