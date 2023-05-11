// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/integrations/safe/SafeFactory.sol";
import "../src/integrations/safe/SafeModule.sol";
import "../src/core/FeeManager.sol";
import "../src/tests/Token.sol";
import "../src/tests/Incrementer.sol";
import "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "safe/Safe.sol";

address constant receiver = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;

contract SafeModuleTest is Test {
    using ECDSA for bytes32;
    SafeModule internal account;
    EntryPoint internal entrypoint;
    SafeFactory internal factory;
    Token internal token;
    Permission[] internal permissions;
    UserOperation[] internal ops;
    Safe internal owner = new Safe();
    uint internal ownerPrivateKey =
        0x18104766cc86e7fb8a7452ac9fb2bccc465a88a9bba2d2d67a5ffd3f459f820f;
    address internal operator = 0xabe1DE8764303a2d4421Ea583ef693CF6cAc109A;
    uint internal operatorPrivateKey =
        0x19ef7c79dbd4115a8df3d576ea6e75362d661def86250fd3ef4557a285359776;
    bytes32[] internal proofs;
    uint[] internal numbers;
    FeeManager internal feeManager;

    function setUp() public {
        entrypoint = new EntryPoint{salt: bytes32("Permissive-v0.0.3")}();
        feeManager = new FeeManager{salt: bytes32("Permissive-v0.0.3")}();
        factory = new SafeFactory{salt: bytes32("Permissive-v0.0.3")}(
            address(entrypoint),
            payable(address(feeManager))
        );
        account = factory.createAccount(
            address(owner),
            0x000000000000000000000000a8b802b27fb4fad58ed28cb6f4ae5061bd432e8c
        );
        token = new Token("USD Coin", "USDC");
        token.mint();
        token.transfer(address(account), 100 ether);
        entrypoint.depositTo{value: 0.11 ether}(address(account));
        Permission memory perm = Permission(
            operator,
            address(token),
            token.transfer.selector,
            hex"f846e202a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990e204a00000000000000000000000000000000000000000000000056bc75e2d63100000",
            address(0),
            10000000000000000,
            0,
            2
        );
        permissions.push(perm);
    }

    function hashPermission(
        Permission memory permission
    ) internal pure returns (bytes32 permHash) {
        permHash = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
                permission.allowed_arguments,
                permission.paymaster,
                permission.expiresAtUnix,
                permission.expiresAtBlock,
                permission.maxUsage
            )
        );
    }

    function testPermissionsGranted() public {
        bytes32 root = keccak256(bytes.concat(hashPermission(permissions[0])));
        vm.prank(address(owner));
        account.setOperatorPermissions(operator, root, 0, 1 ether);
        assert(account.remainingFeeForOperator(operator) == 1 ether);
        assert(account.remainingValueForOperator(operator) == 0);
        assert(account.operatorPermissions(operator) == root);
    }

    function testTransactionPasses() public {
        testPermissionsGranted();
        UserOperation memory op = UserOperation(
            address(account),
            account.getNonce(),
            hex"",
            hex"",
            10000000,
            10000000,
            10000,
            10000,
            10000,
            hex"",
            hex""
        );
        uint computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(token),
            0,
            abi.encodePacked(
                token.transfer.selector,
                hex"f842a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990a00000000000000000000000000000000000000000000000056bc75e2d630fffff"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            operatorPrivateKey,
            entrypoint.getUserOpHash(op).toEthSignedMessageHash()
        );
        op.signature = abi.encodePacked(r, s, v);
        ops.push(op);
        uint oldFeeManagerBalance = address(feeManager).balance;
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        entrypoint.handleOps(ops, payable(address(this)));
        assert(
            (feeManager.fee() * computedFee) / 10000 ==
                address(feeManager).balance - oldFeeManagerBalance
        );
        assert(
            token.balanceOf(address(account)) == 100 ether - 0x56bc75e2d630fffff
        );
        assert(
            token.balanceOf(0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990) ==
                0x56bc75e2d630fffff
        );
    }

    function testNoArgs() external {
        testTransactionPasses();
        Incrementer incr = new Incrementer();
        Permission memory perm = Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"c0",
            address(0),
            1713986312,
            0,
            0
        );
        ops.pop();
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(hashPermission(perm)));
        vm.prank(address(owner));
        account.setOperatorPermissions(operator, root, 0, 0.11 ether);
        UserOperation memory op = UserOperation(
            address(account),
            account.getNonce(),
            hex"",
            abi.encodeWithSelector(
                account.execute.selector,
                address(incr),
                0,
                abi.encodePacked(incr.increment.selector, hex"c0"),
                permissions[0],
                proofs
            ),
            10000000,
            10000000,
            10000,
            10000,
            10000,
            hex"",
            hex""
        );
        uint computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(incr.increment.selector, hex"c0"),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            operatorPrivateKey,
            entrypoint.getUserOpHash(op).toEthSignedMessageHash()
        );
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        entrypoint.handleOps(ops, payable(address(this)));
        assert(incr.value() == 1);
    }

    receive() external payable {}
}
