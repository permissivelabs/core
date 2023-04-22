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

library DomainSeparatorUtils {
    function buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash,
        address target
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    block.chainid,
                    target
                )
            );
    }

    function efficientHash(
        bytes32 a,
        bytes32 b
    ) public pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

contract SigUtils {
    bytes32 public DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    bytes32 public constant TYPEHASH =
        0xcd3966ea44fb027b668c722656f7791caa71de9073b3cbb77585cc6fa97ce82e;

    function getStructHash(
        Permit memory _permit
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _permit.operator,
                    _permit.merkleRootPermissions,
                    _permit.maxValue,
                    _permit.maxFee
                )
            );
    }

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
    SigUtils internal utils;

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
        proofs.push(hashPermission(perm));
        utils = new SigUtils(
            DomainSeparatorUtils.buildDomainSeparator(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Permissive Account")),
                keccak256(bytes("0.0.3")),
                address(account)
            )
        );
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
        bytes32 root = DomainSeparatorUtils.efficientHash(proofs[0], proofs[0]);
        vm.prank(owner);
        bytes32 digest = utils.getTypedDataHash(
            Permit(operator, root, 0, 1 ether)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(
            operator,
            root,
            0,
            1 ether,
            abi.encodePacked(r, s, v)
        );
        assert(account.remainingFeeForOperator(operator) == 1 ether);
        assert(account.remainingValueForOperator(operator) == 0);
        assert(account.operatorPermissions(operator) == root);
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
        assert(
            token.balanceOf(address(account)) == 100 ether - 0x56bc75e2d630fffff
        );
        assert(
            token.balanceOf(0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990) ==
                0x56bc75e2d630fffff
        );
    }

    receive() external payable {}
}
