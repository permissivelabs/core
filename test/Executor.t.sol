// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissionExecutor.sol";
import "../src/core/FeeManager.sol";
import "./interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

address constant CONIC = 0x9aE380F0272E2162340a5bB646c354271c0F5cFC;
address constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant OPENSEA = 0x9aE380F0272E2162340a5bB646c354271c0F5cFC;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract ExecutorTest is Test {
    using PermissionLib for Permission;

    PermissionExecutor executor;
    FeeManager feeManager;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event FeePaid(address indexed, uint256);
    event PermissionUsed(
        bytes32 indexed permHash,
        address dest,
        uint256 value,
        bytes func,
        Permission permission,
        uint256 gasFee
    );

    uint256 fork;

    function setUp() public {
        fork = vm.createFork(vm.envString("RPC_1"));
        vm.selectFork(fork);
        feeManager = new FeeManager();
        feeManager.initialize(address(this));
        executor = new PermissionExecutor(feeManager);
    }

    function testTransferERC20(uint256 fee, Permission calldata perm) public {
        vm.assume(fee < 1 ether);
        deal(CONIC, address(this), 12386961635);
        vm.deal(address(this), fee);
        vm.expectEmit(true, true, false, true, CONIC);
        vm.expectEmit(true, false, false, true, address(feeManager));
        emit Transfer(
            address(this),
            0x1f9090aaE28b8a3dCeaDf281B0F12828e676c326,
            12386961635
        );
        emit FeePaid(address(this), (fee * feeManager.fee()) / 10000);
        (bool success, bytes memory returnData) = address(executor)
            .delegatecall(
                abi.encodeWithSelector(
                    executor.execute.selector,
                    CONIC,
                    0,
                    bytes.concat(
                        ERC20.transfer.selector,
                        hex"f84300a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
                    ),
                    perm,
                    hex"",
                    fee
                )
            );
        assert(success == true);
        assert(uint256(bytes32(returnData)) == 1);
        assert(
            ERC20(CONIC).balanceOf(
                0x1f9090aaE28b8a3dCeaDf281B0F12828e676c326
            ) == 12386961635
        );
        (success, returnData) = address(executor).delegatecall(
            abi.encodeWithSelector(
                executor.execute.selector,
                CONIC,
                0,
                bytes.concat(
                    ERC20.transfer.selector,
                    hex"f84300a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
                ),
                perm,
                hex"",
                fee
            )
        );
        assert(success == false);
        assert(
            keccak256(returnData) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("ERC20: transfer amount exceeds balance")
                    )
                )
        );
    }

    function testSwap(uint256 fee, Permission calldata perm) public {
        vm.assume(fee < 1 ether);
        deal(CONIC, address(this), 1 ether);
        vm.deal(address(this), fee);
        ERC20(CONIC).approve(UNISWAP_ROUTER, 1 ether);
        vm.expectEmit(true, false, false, true, address(feeManager));
        vm.expectEmit(true, false, false, true, address(this));
        emit FeePaid(address(this), (fee * feeManager.fee()) / 10000);
        emit PermissionUsed(
            perm.hash(),
            UNISWAP_ROUTER,
            0,
            bytes.concat(
                ISwapRouter.exactInput.selector,
                hex"f9012a00a00000000000000000000000000000000000000000000000000000000000000020a000000000000000000000000000000000000000000000000000000000000000a0a00000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496a0000000000000000000000000000000000000000000000000003c012523e0eb80a00000000000000000000000000000000000000000000000000de0b6b3a7640000a00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002ba09ae380f0272e2162340a5bb646c354271c0f5cfc002710c02aaa39b223fe8d0aa00e5c4f27ead9083c756cc2000000000000000000000000000000000000000000"
            ),
            perm,
            fee
        );
        (bool success, bytes memory returnData) = address(executor)
            .delegatecall(
                abi.encodeWithSelector(
                    executor.execute.selector,
                    UNISWAP_ROUTER,
                    0,
                    bytes.concat(
                        ISwapRouter.exactInput.selector,
                        hex"f9012a00a00000000000000000000000000000000000000000000000000000000000000020a000000000000000000000000000000000000000000000000000000000000000a0a00000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496a0000000000000000000000000000000000000000000000000003c012523e0eb80a00000000000000000000000000000000000000000000000000de0b6b3a7640000a00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002ba09ae380f0272e2162340a5bb646c354271c0f5cfc002710c02aaa39b223fe8d0aa00e5c4f27ead9083c756cc2000000000000000000000000000000000000000000"
                    ),
                    perm,
                    hex"",
                    fee
                )
            );
        assert(success == true);
        assert(
            ERC20(WETH).balanceOf(address(this)) == uint256(bytes32(returnData))
        );
    }

    receive() external payable {}

    fallback() external payable {}
}
