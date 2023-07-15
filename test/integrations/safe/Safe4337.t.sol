// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "safe/SafeL2.sol";
import "../../../src/integrations/safe/Safe4337.sol";
import "../../../src/core/PermissionExecutor.sol";
import "../../../src/core/PermissionVerifier.sol";
import "../../../src/core/PermissionRegistry.sol";
import "../../../src/core/FeeManager.sol";
import "account-abstraction/core/EntryPoint.sol";
import "../../interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

address constant CONIC = 0x9aE380F0272E2162340a5bB646c354271c0F5cFC;
address constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract Safe4337Test is Test {
    using PermissionLib for Permission;
    using ECDSA for bytes32;

    SafeL2 safe;
    Safe4337Module permissive;
    EntryPoint entryPoint;
    PermissionVerifier verifier;
    PermissionExecutor executor;
    PermissionRegistry registry;
    FeeManager feeManager;

    UserOperation[] ops;
    bytes32[] proofs;
    address[] owners;

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

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("RPC_1"));
        vm.selectFork(fork);
        safe = new SafeL2();
        entryPoint = new EntryPoint();
        feeManager = new FeeManager();
        registry = new PermissionRegistry();
        verifier = new PermissionVerifier(registry);
        executor = new PermissionExecutor(feeManager);
        permissive = new Safe4337Module(entryPoint, verifier, executor);
        owners.push(address(this));
        safe.setup(
            owners,
            1,
            address(permissive),
            abi.encodeWithSelector(permissive.enableMyself.selector),
            address(permissive),
            address(0),
            0,
            payable(address(0))
        );
    }

    function testSwap(uint256 operatorPrivateKey) public {
        validPrivateKey(operatorPrivateKey);
        vm.assume(vm.addr(operatorPrivateKey).code.length == 0);
        Permission memory perm = Permission({
            operator: vm.addr(operatorPrivateKey),
            to: UNISWAP_ROUTER,
            maxUsage: 100,
            selector: ISwapRouter.exactInput.selector,
            paymaster: address(0),
            validAfter: 0,
            validUntil: 0,
            dataValidator: address(0),
            allowed_arguments: hex"f9013ec20200e202a00000000000000000000000000000000000000000000000000000000000000020e202a000000000000000000000000000000000000000000000000000000000000000a0e202a00000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496e202a0000000000000000000000000000000000000000000000000003c012523e0eb80e202a00000000000000000000000000000000000000000000000000de0b6b3a7640000e202a00000000000000000000000000000000000000000000000000000000000000000e202a0000000000000000000000000000000000000000000000000000000000000002be202a09ae380f0272e2162340a5bb646c354271c0f5cfc002710c02aaa39b223fe8d0ae202a00e5c4f27ead9083c756cc2000000000000000000000000000000000000000000"
        });
        vm.prank(address(safe));
        registry.setOperatorPermissions(
            vm.addr(operatorPrivateKey),
            keccak256(bytes.concat(perm.hash()))
        );
        deal(CONIC, address(safe), 1 ether);
        vm.deal(address(safe), 1 ether);
        vm.prank(address(safe));
        ERC20(CONIC).approve(UNISWAP_ROUTER, 1 ether);
        // vm.expectEmit(true, false, false, true, address(feeManager));
        // vm.expectEmit(true, false, false, true, address(this));
        UserOperation memory op = UserOperation({
            sender: address(safe),
            nonce: entryPoint.getNonce(address(safe), 0),
            initCode: hex"",
            callData: abi.encodeWithSelector(
                permissive.execute.selector,
                perm.hash(),
                UNISWAP_ROUTER,
                0,
                bytes.concat(
                    ISwapRouter.exactInput.selector,
                    hex"f9012a00a00000000000000000000000000000000000000000000000000000000000000020a000000000000000000000000000000000000000000000000000000000000000a0a00000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496a0000000000000000000000000000000000000000000000000003c012523e0eb80a00000000000000000000000000000000000000000000000000de0b6b3a7640000a00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002ba09ae380f0272e2162340a5bb646c354271c0f5cfc002710c02aaa39b223fe8d0aa00e5c4f27ead9083c756cc2000000000000000000000000000000000000000000"
                ),
                perm,
                proofs,
                0
            ),
            callGasLimit: 10000000,
            verificationGasLimit: 10000000,
            preVerificationGas: 10000000,
            maxFeePerGas: 10000000,
            maxPriorityFeePerGas: 10000000,
            paymasterAndData: hex"",
            signature: hex""
        });
        uint256 fee = verifier.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            permissive.execute.selector,
            UNISWAP_ROUTER,
            0,
            bytes.concat(
                ISwapRouter.exactInput.selector,
                hex"f9012a00a00000000000000000000000000000000000000000000000000000000000000020a000000000000000000000000000000000000000000000000000000000000000a0a00000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496a0000000000000000000000000000000000000000000000000003c012523e0eb80a00000000000000000000000000000000000000000000000000de0b6b3a7640000a00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002ba09ae380f0272e2162340a5bb646c354271c0f5cfc002710c02aaa39b223fe8d0aa00e5c4f27ead9083c756cc2000000000000000000000000000000000000000000"
            ),
            perm,
            proofs,
            fee
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            operatorPrivateKey,
            entryPoint.getUserOpHash(op).toEthSignedMessageHash()
        );
        op.signature = abi.encodePacked(r, s, v);
        ops.push(op);
        uint256 oldBalance = ERC20(WETH).balanceOf(
            address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)
        );
        entryPoint.handleOps(ops, payable(address(this)));
        assert(
            ERC20(WETH).balanceOf(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496) >
                oldBalance
        );
    }

    function validPrivateKey(uint256 privateKey) internal pure {
        vm.assume(
            privateKey <
                115792089237316195423570985008687907852837564279074904382605163141518161494337 &&
                privateKey != 0
        );
    }

    receive() external payable {}

    fallback() external payable {}
}
