// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/FeeManager.sol";

contract FeeManagerTest is Test {
    FeeManager feeManager;

    event FeePaid(address indexed from, uint256 amount);

    function setUp() public {
        feeManager = new FeeManager();
        feeManager.initialize(address(this));
    }

    function testSetFee(uint24 fee) public {
        feeManager.setFee(fee);
        assert(feeManager.fee() == fee);
    }

    function testInitialized(address owner) public {
        FeeManager _feeManager = new FeeManager();
        assert(_feeManager.owner() == address(this));
        _feeManager.initialize(owner);
        assert(_feeManager.owner() == owner);
        vm.expectRevert();
        _feeManager.initialize(owner);
    }

    function testFeePaid(uint256 amount) public {
        vm.deal(address(this), amount);
        vm.expectEmit(true, false, false, true, address(feeManager));
        emit FeePaid(address(this), amount);
        feeManager.pay{value: amount}();
    }

    receive() external payable {}

    fallback() external payable {}
}
