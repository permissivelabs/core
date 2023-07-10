// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/utils/AllowanceCalldata.sol";

contract AllowanceCalldataTest is Test {
    function testArgLength() public {
        vm.expectRevert("Invalid arguments length");
        AllowanceCalldata.isAllowedCalldata(
            hex"ceca02880de0b6b3a7640000c20301",
            hex"c102",
            0
        );
    }

    function testValue() public {
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"cbca02880de0b6b3a7640000",
                hex"c9880de0b6b3a7640000",
                1 ether
            ) == true
        );
        vm.expectRevert("msg.value not corresponding to allowed value");
        AllowanceCalldata.isAllowedCalldata(
            hex"cbca02880de0b6b3a7640000",
            hex"c9880de0b6b3a7640000",
            0.01 ether
        );
        AllowanceCalldata.isAllowedCalldata(
            hex"cbca02880de0b6b3a7640000",
            hex"c9881de0b6b3a7640000",
            1 ether
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"cbca01880de0b6b3a7640000",
                hex"c9880de0b6b3a7640000",
                1 ether
            ) == false
        );
    }

    function testEQ() public {
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20201",
                hex"ca880de0b6b3a764000001",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20201",
                hex"cc880de0b6b3a7640000820001",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20201",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20201",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == false
        );
    }

    function testNE() public {
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20101",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20101",
                hex"ca880de0b6b3a764000001",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"ceca02880de0b6b3a7640000c20101",
                hex"cc880de0b6b3a7640000820001",
                1 ether
            ) == true
        );
    }

    function testANY() public {
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"cdca02880de0b6b3a7640000c100",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == true
        );
    }

    function testGT() public {
        vm.expectRevert();
        // test overflow (uint256)
        AllowanceCalldata.isAllowedCalldata(
            hex"efca02880de0b6b3a7640000e303a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            hex"ec880de0b6b3a7640000a2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            1 ether
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"eeca02880de0b6b3a7640000e203a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                hex"ea880de0b6b3a7640000a0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"eeca02880de0b6b3a7640000e203a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                hex"ea880de0b6b3a7640000a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"eeca02880de0b6b3a7640000e203a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                hex"ea880de0b6b3a7640000a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd",
                1 ether
            ) == false
        );
    }

    function testLT() public {
        vm.expectRevert();
        // test overflow (uint256)
        AllowanceCalldata.isAllowedCalldata(
            hex"efca02880de0b6b3a7640000e303a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            hex"ec880de0b6b3a7640000a2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            1 ether
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"eeca02880de0b6b3a7640000e203a0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                hex"ea880de0b6b3a7640000a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"eeca02880de0b6b3a7640000e203a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                hex"ea880de0b6b3a7640000a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"eeca02880de0b6b3a7640000e203a0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe",
                hex"ea880de0b6b3a7640000a0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                1 ether
            ) == false
        );
    }

    function testAND() public {
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d7ca02880de0b6b3a7640000cb05c9c20301c20403c20202",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d4ca02880de0b6b3a7640000c805c6c20301c20403",
                hex"ca880de0b6b3a764000001",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d4ca02880de0b6b3a7640000c805c6c20301c20403",
                hex"cc880de0b6b3a7640000c20202",
                1 ether
            ) == false
        );
    }

    function testOR() public {
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d7ca02880de0b6b3a7640000cb06c9c20201c20202c20203",
                hex"ca880de0b6b3a764000001",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d7ca02880de0b6b3a7640000cb06c9c20201c20202c20203",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d7ca02880de0b6b3a7640000cb06c9c20201c20202c20203",
                hex"ca880de0b6b3a764000003",
                1 ether
            ) == true
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d7ca02880de0b6b3a7640000cb06c9c20201c20202c20203",
                hex"ca880de0b6b3a764000004",
                1 ether
            ) == false
        );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"d7ca02880de0b6b3a7640000cb06c9c20201c20202c20203",
                hex"cc880de0b6b3a7640000c20202",
                1 ether
            ) == false
        );
    }

    function test2Depth() public {
        // assert(
        //     AllowanceCalldata.isAllowedCalldata(
        //         hex"e4ca02880de0b6b3a7640000d806d6cc06cac402820667c402820668c805c6c20301c20403",
        //         hex"cc880de0b6b3a7640000820667",
        //         1 ether
        //     ) == true
        // );
        assert(
            AllowanceCalldata.isAllowedCalldata(
                hex"e4ca02880de0b6b3a7640000d806d6cc06cac402820667c402820668c805c6c20301c20403",
                hex"ca880de0b6b3a764000002",
                1 ether
            ) == true
        );
    }

    function testABI() public {
        assert(
            keccak256(
                AllowanceCalldata.RLPtoABI(
                    hex"f88500a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a00000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000002e25208e3a07cdc7b5e5df3309e54fb9651f61bb153fe807bcdda795dc0d2dd313ae889b979"
                )
            ) ==
                keccak256(
                    abi.encode(
                        address(0x1f9090aaE28b8a3dCeaDf281B0F12828e676c326),
                        true,
                        12386961635,
                        0x7cdc7b5e5df3309e54fb9651f61bb153fe807bcdda795dc0d2dd313ae889b979
                    )
                )
        );
    }

    function testFill(
        RLPReader.RLPItem[] calldata fuzzArray,
        uint256 index,
        uint256 length
    ) public {
        vm.assume(index < fuzzArray.length);
        vm.assume(index < length && length < 100);
        RLPReader.RLPItem[] memory filledArray = AllowanceCalldata.fillArray(
            fuzzArray,
            index,
            length
        );
        assert(filledArray.length == length);
        for (uint256 i = 0; i < length; i++) {
            assert(filledArray[i].len == fuzzArray[index].len);
            assert(filledArray[i].memPtr == fuzzArray[index].memPtr);
        }
    }
}
