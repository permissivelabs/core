// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissiveAccount.sol";
import "../src/core/FeeManager.sol";
import "../src/tests/Token.sol";
import "../lib/account-abstraction/contracts/core/EntryPoint.sol";

address constant receiver = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;

struct Permit {
    address operator;
    bytes32 merkleRootPermissions;
    uint256 maxValue;
    uint256 maxFee;
}

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0xcd3966ea44fb027b668c722656f7791caa71de9073b3cbb77585cc6fa97ce82e;

    // computes the hash of a permit
    function getStructHash(
        Permit memory _permit
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    _permit.operator,
                    _permit.merkleRootPermissions,
                    _permit.maxValue,
                    _permit.maxFee
                )
            );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(
        Permit memory _permit
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(_permit)
                )
            );
    }
}

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
    uint[] internal numbers;
    FeeManager internal feeManager;

    function setUp() public {
        entrypoint = new EntryPoint();
        operator = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        feeManager = new FeeManager();
        account = new PermissiveAccount(
            address(entrypoint),
            payable(address(feeManager))
        );
        account.initialize(owner);
        token = new Token("USD Coin", "USDC");
        token.mint();
        token.transfer(address(account), 100 ether);
        entrypoint.depositTo{value: 1 ether}(address(account));
        Permission memory perm = Permission(
            operator,
            address(token),
            token.transfer.selector,
            hex"f846e202a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990e204a00000000000000000000000000000000000000000000000056bc75e2d63100000",
            address(0),
            10000000000000000,
            0,
            100
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
        SigUtils utils = new SigUtils();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            0xb7e2c8abccd54967814ebafa49a8ac92191b81d4698ec3089a2f1dde65b71d66,
            utils.getTypedDataHash(
                Permit(operator, hashPermission(permissions[0]), 0, 1 ether)
            )
        );
        account.setOperatorPermissions(
            operator,
            hashPermission(permissions[0]),
            0,
            1 ether,
            abi.encodePacked(r, s, v)
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
                abi.encodePacked(
                    token.transfer.selector,
                    hex"f842a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990a00000000000000000000000000000000000000000000000056bc75e2d630fffff"
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

    function testABI() public {
        numbers.push(1);
        numbers.push(2);
        numbers.push(3);
        numbers.push(4);
        console.logBytes(abi.encode([1, 2, 3, 4]));
        console.logBytes(abi.encode(numbers, 15));
    }

    receive() external payable {}
}
