// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissiveAccount.sol";
import "../src/tests/Token.sol";
import "../src/interfaces/Permission.sol";
import "../lib/account-abstraction/contracts/core/EntryPoint.sol";

address constant receiver = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;

contract PermissiveAccountTest is Test {
    PermissiveAccount internal account;
    EntryPoint internal entrypoint;
    address internal operator;
    Token internal token;
    Permission[] internal permissions;
    UserOperation[] internal ops;
    address internal owner = 0xa8b802B27FB4FAD58Ed28Cb6F4Ae5061bD432e8c;
    uint internal ownerPrivateKey =
        0x18104766cc86e7fb8a7452ac9fb2bccc465a88a9bba2d2d67a5ffd3f459f820f;
    bytes32[] internal proofs;

    function setUp() public {
        entrypoint = new EntryPoint();
        operator = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        account = new PermissiveAccount(address(entrypoint));
        account.initialize(owner);
        token = new Token("USD Coin", "USDC");
        token.mint();
        token.transfer(address(account), 100 ether);
        entrypoint.depositTo{value: 1 ether}(address(account));
        Permission memory perm = Permission(
            operator,
            address(token),
            token.transfer.selector,
            hex"e3d60194690b9a9e9aa1c9db991c7721a92d351db4fac990cb0389056bc75e2d63100000",
            address(0),
            10000000000000000,
            0
        );
        permissions.push(perm);
    }

    function hashPermission(
        Permission memory permission
    ) internal pure returns (bytes32 h) {
        h = keccak256(
            abi.encode(
                permission.operator,
                permission.to,
                permission.selector,
                permission.paymaster,
                permission.expiresAtUnix,
                permission.expiresAtBlock
            )
        );
    }

    function testPermissionsGranted() public {
        vm.prank(owner);
        account.setOperatorPermissions(
            operator,
            hashPermission(permissions[0]),
            0,
            1 ether
        );
        assert(account.remainingFeeForOperator(operator) == 1 ether);
        assert(account.remainingValueForOperator(operator) == 0);
        assert(
            account.operatorPermissions(operator) ==
                hashPermission(permissions[0])
        );
    }

    function testTransactionPasses() public {
        testPermissionsGranted();
        vm.prank(address(this));
        UserOperation memory op = UserOperation(
            address(account),
            1,
            hex"",
            abi.encodeWithSelector(
                account.execute.selector,
                address(token),
                0,
                abi.encodeWithSelector(
                    token.transfer.selector,
                    receiver,
                    50 ether
                ),
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPrivateKey,
            entrypoint.getUserOpHash(op)
        );
        op.signature = abi.encodePacked(r, s, v);
        ops.push(op);
        entrypoint.handleOps(ops, payable(address(this)));
    }

    receive() external payable {
        console.log("Received refund", msg.value);
    }
}
