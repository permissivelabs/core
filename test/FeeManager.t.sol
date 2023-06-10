// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/core/FeeManager.sol";

contract FeeManagerTest is Test {
    FeeManager feeManager;

    function setUp() public {
        feeManager = new FeeManager();
        feeManager.initialize(address(667));
    }

    function testInitialize() public {
        vm.expectRevert();
        feeManager.initialize(address(0));
    }

    function testSetFee(uint24 _fee) public {
        vm.prank(address(667));
        feeManager.setFee(uint24(_fee));
        assert(feeManager.fee() == uint24(_fee));
    }

    function testDeposit() public {
        payable(address(feeManager)).transfer(1 ether);
    }

    function testWithdraw() public {
        testDeposit();
        vm.prank(address(667));
        feeManager.withdraw();
        assert(payable(feeManager).balance == 0);
    }

    function testInvalidOwner() public {
        vm.expectRevert();
        feeManager.setFee(2);
        vm.expectRevert();
        feeManager.withdraw();
    }
}
