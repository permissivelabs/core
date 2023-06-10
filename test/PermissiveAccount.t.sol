// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissiveAccount.sol";
import "../src/core/PermissiveFactory.sol";
import "../src/core/FeeManager.sol";
import "../src/tests/Token.sol";
import "../src/tests/Incrementer.sol";
import "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./mock/Aggregator.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "./mock/DataValidator.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

address constant receiver = 0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990;

struct UserOpsPerAggregator {
    UserOperation[] userOps;
    // aggregator address
    IAggregator aggregator;
    // aggregated signature
    bytes signature;
}

library DomainSeparatorUtils {
    function buildDomainSeparator(bytes32 typeHash, bytes32 nameHash, bytes32 versionHash, address target)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, target));
    }

    function efficientHash(bytes32 a, bytes32 b) public pure returns (bytes32 value) {
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

    bytes32 public constant TYPEHASH = 0xd7e1e23484f808c5620ce8d904e88d7540a3eeb37ac94e636726ed53571e4e3c;

    function getStructHash(PermissionSet memory _permit) internal pure returns (bytes32) {
        return keccak256(abi.encode(TYPEHASH, _permit.operator, _permit.merkleRootPermissions));
    }

    function getTypedDataHash(PermissionSet memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }
}

contract PermissiveAccountTest is Test {
    using ECDSA for bytes32;
    using PermissionLib for PermissionLib.Permission;

    PermissiveAccount internal account;
    EntryPoint internal entrypoint;
    PermissiveFactory internal factory;
    Token internal token;
    PermissionLib.Permission[] internal permissions;
    UserOperation[] internal ops;
    UserOpsPerAggregator[] internal agops;
    address internal owner = 0xa8b802B27FB4FAD58Ed28Cb6F4Ae5061bD432e8c;
    uint256 internal ownerPrivateKey = 0x18104766cc86e7fb8a7452ac9fb2bccc465a88a9bba2d2d67a5ffd3f459f820f;
    address internal operator = 0xabe1DE8764303a2d4421Ea583ef693CF6cAc109A;
    uint256 internal operatorPrivateKey = 0x19ef7c79dbd4115a8df3d576ea6e75362d661def86250fd3ef4557a285359776;
    bytes32[] internal proofs;
    uint256[] internal numbers;
    FeeManager internal feeManager;
    SigUtils internal utils;

    function setUp() public {
        entrypoint = new EntryPoint{salt: bytes32("Permissive-v0.0.4")}();
        feeManager = new FeeManager{salt: bytes32("Permissive-v0.0.4")}();
        PermissiveAccount impl = new PermissiveAccount(
            address(entrypoint),
            payable(address(feeManager))
        );
        factory = new PermissiveFactory{salt: bytes32("Permissive-v0.0.4")}(
            address(impl)
        );
        account = factory.createAccount(owner, 0x000000000000000000000000a8b802b27fb4fad58ed28cb6f4ae5061bd432e8c);
        token = new Token("USD Coin", "USDC");
        token.mint();
        token.transfer(address(account), 100 ether);
        entrypoint.depositTo{value: 0.11 ether}(address(account));
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(token),
            token.transfer.selector,
            hex"f869e202a00000000000000000000000000000000000000000000000000000000000000000e202a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990e204a00000000000000000000000000000000000000000000000056bc75e2d63100000",
            address(0),
            0,
            0,
            0,
            DataValidation(address(0), address(0), hex"")
        );
        permissions.push(perm);
        utils = new SigUtils(
            DomainSeparatorUtils.buildDomainSeparator(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Permissive Account")),
                keccak256(bytes("v0.0.4")),
                address(account)
            )
        );
    }

    function testPermissionsGranted() public {
        bytes32 root = keccak256(bytes.concat(permissions[0].hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        assert(account.operatorPermissions(operator) == root);
    }

    function testTransactionPasses() public {
        testPermissionsGranted();
        UserOperation memory op = UserOperation(
            address(account), account.getNonce(), hex"", hex"", 10000000, 10000000, 10000, 10000, 10000, hex"", hex""
        );
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(token),
            0,
            abi.encodePacked(
                token.transfer.selector,
                hex"f863a00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990a00000000000000000000000000000000000000000000000056bc75e2d630fffff"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        ops.push(op);
        uint256 oldFeeManagerBalance = address(feeManager).balance;
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        entrypoint.handleOps(ops, payable(address(this)));
        assert((feeManager.fee() * computedFee) / 10000 == address(feeManager).balance - oldFeeManagerBalance);
        assert(token.balanceOf(address(account)) == 100 ether - 0x56bc75e2d630fffff);
        assert(token.balanceOf(0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990) == 0x56bc75e2d630fffff);
    }

    function testNoArgs() external {
        testTransactionPasses();
        Incrementer incr = new Incrementer();
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"e3e202a00000000000000000000000000000000000000000000000000000000000000000",
            address(0),
            0,
            0,
            0,
            DataValidation(address(0), address(0), hex"")
        );
        ops.pop();
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        UserOperation memory op = UserOperation(
            address(account),
            account.getNonce(),
            hex"",
            abi.encodeWithSelector(
                account.execute.selector,
                address(incr),
                0,
                abi.encodePacked(
                    incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
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
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        entrypoint.handleOps(ops, payable(address(this)));
        assert(incr.value() == 1);
    }

    function testValidUntil() external {
        Incrementer incr = new Incrementer();
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"e3e202a00000000000000000000000000000000000000000000000000000000000000000",
            address(0),
            100, // valid until 100
            0,
            0,
            DataValidation(address(0), address(0), hex"")
        );
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        UserOperation memory op = UserOperation(
            address(account),
            account.getNonce(),
            hex"",
            abi.encodeWithSelector(
                account.execute.selector,
                address(incr),
                0,
                abi.encodePacked(
                    incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
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
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        vm.warp(101);
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA22 expired or not due"));
        entrypoint.handleOps(ops, payable(address(this)));
        vm.warp(100);
        entrypoint.handleOps(ops, payable(address(this)));
        assert(incr.value() == 1);
    }

    function testValidAfter() external {
        Incrementer incr = new Incrementer();
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"e3e202a00000000000000000000000000000000000000000000000000000000000000000",
            address(0),
            0,
            100, // valid after 100
            0,
            DataValidation(address(0), address(0), hex"")
        );
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        UserOperation memory op = UserOperation(
            address(account),
            account.getNonce(),
            hex"",
            abi.encodeWithSelector(
                account.execute.selector,
                address(incr),
                0,
                abi.encodePacked(
                    incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
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
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        vm.warp(99);
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA22 expired or not due"));
        entrypoint.handleOps(ops, payable(address(this)));
        vm.warp(100);
        entrypoint.handleOps(ops, payable(address(this)));
        assert(incr.value() == 1);
    }

    function testValue() external {
        Incrementer incr = new Incrementer();
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"e3e202a00000000000000000000000000000000000000000000000000000000000000000",
            address(0),
            0,
            0,
            0,
            DataValidation(address(0), address(0), hex"")
        );
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        UserOperation memory op = UserOperation(
            address(account), account.getNonce(), hex"", hex"", 10000000, 10000000, 10000, 10000, 10000, hex"", hex""
        );
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000001"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector, 0, "AA23 reverted: msg.value not matching with provided value"
            )
        );
        entrypoint.handleOps(ops, payable(address(this)));
        ops.pop();
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v3, bytes32 r3, bytes32 s3) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r3, s3, v3);
        ops.push(op);
        entrypoint.handleOps(ops, payable(address(this)));
        assert(incr.value() == 1);
    }

    function testBlokchainDataValidationFailsBecauseInvalidTarget() external {
        ERC721 nft = new ERC721("Bored Ape Yatch Club", "BAYC");
        DataValidator validator = new DataValidator(nft);
        Incrementer incr = new Incrementer();
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"e3e202a00000000000000000000000000000000000000000000000000000000000000000",
            address(0),
            0,
            0,
            0,
            DataValidation(address(validator), address(0), abi.encode(address(account), 0))
        );
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        UserOperation memory op = UserOperation(
            address(account), account.getNonce(), hex"", hex"", 10000000, 10000000, 10000, 10000, 10000, hex"", hex""
        );
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA23 reverted: Invalid data"));
        entrypoint.handleOps(ops, payable(address(this)));
    }

    function testBlokchainDataValidationFailsBecauseInvalidState() external {
        ERC721PresetMinterPauserAutoId nft = new ERC721PresetMinterPauserAutoId(
            "Bored Ape Yatch Club",
            "BAYC",
            ""
        );
        DataValidator validator = new DataValidator(nft);
        Incrementer incr = new Incrementer();
        PermissionLib.Permission memory perm = PermissionLib.Permission(
            operator,
            address(incr),
            incr.increment.selector,
            hex"e3e202a00000000000000000000000000000000000000000000000000000000000000000",
            address(0),
            0,
            0,
            0,
            DataValidation(address(validator), address(nft), abi.encode(address(account), 0))
        );
        permissions.pop();
        permissions.push(perm);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        bytes32 digest = utils.getTypedDataHash(PermissionSet(operator, root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        account.setOperatorPermissions(PermissionSet(operator, root), abi.encodePacked(r, s, v));
        UserOperation memory op = UserOperation(
            address(account), account.getNonce(), hex"", hex"", 10000000, 10000000, 10000, 10000, 10000, hex"", hex""
        );
        uint256 computedFee = account.computeGasFee(op);
        op.callData = abi.encodeWithSelector(
            account.execute.selector,
            address(incr),
            0,
            abi.encodePacked(
                incr.increment.selector, hex"e1a00000000000000000000000000000000000000000000000000000000000000000"
            ),
            permissions[0],
            proofs,
            computedFee
        );
        (uint8 v2, bytes32 r2, bytes32 s2) =
            vm.sign(operatorPrivateKey, entrypoint.getUserOpHash(op).toEthSignedMessageHash());
        op.signature = abi.encodePacked(r2, s2, v2);
        ops.push(op);
        payable(account).transfer((feeManager.fee() * computedFee) / 10000);
        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA23 reverted: ERC721: invalid token ID")
        );
        entrypoint.handleOps(ops, payable(address(this)));
        nft.mint(address(account));
        entrypoint.handleOps(ops, payable(address(this)));
        assert(incr.value() == 1);
    }

    // function testContractSigner() external {
    //     Aggregator contractOperator = new Aggregator();
    //     PermissionLib.Permission memory perm = PermissionLib.Permission(
    //         address(contractOperator),
    //         address(token),
    //         token.transfer.selector,
    //         hex"f869e202a00000000000000000000000000000000000000000000000000000000000000000e202a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990e204a00000000000000000000000000000000000000000000000056bc75e2d63100000",
    //         address(0),
    //         0,
    //         0,
    //         0,
    //         DataValidation(address(0), address(0), hex"")
    //     );
    //     bytes32 root = keccak256(bytes.concat(perm.hash()));
    //     bytes32 digest = utils.getTypedDataHash(
    //         PermissionSet(address(contractOperator), root)
    //     );
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
    //     account.setOperatorPermissions(
    //         PermissionSet(address(contractOperator), root),
    //         abi.encodePacked(r, s, v)
    //     );
    //     UserOperation memory op = UserOperation(
    //         address(account),
    //         account.getNonce(),
    //         hex"",
    //         hex"",
    //         10000000,
    //         10000000,
    //         10000,
    //         10000,
    //         10000,
    //         hex"",
    //         hex""
    //     );
    //     uint256 computedFee = account.computeGasFee(op);
    //     op.callData = abi.encodeWithSelector(
    //         account.execute.selector,
    //         address(token),
    //         0,
    //         abi.encodePacked(
    //             token.transfer.selector,
    //             hex"f863a00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000690b9a9e9aa1c9db991c7721a92d351db4fac990a00000000000000000000000000000000000000000000000056bc75e2d630fffff"
    //         ),
    //         perm,
    //         proofs,
    //         computedFee
    //     );
    //     (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
    //         operatorPrivateKey,
    //         entrypoint.getUserOpHash(op).toEthSignedMessageHash()
    //     );
    //     op.signature = abi.encodePacked(r1, s1, v1);
    //     contractOperator.sign(op.signature);
    //     ops.push(op);
    //     agops.push(UserOpsPerAggregator(ops, contractOperator, hex""));
    //     uint256 oldFeeManagerBalance = address(feeManager).balance;
    //     payable(account).transfer((feeManager.fee() * computedFee) / 10000);
    //     entrypoint.handleAggregatedOps(
    //         [IEntryPoint.UserOpsPerAggregator(ops, contractOperator, hex"")],
    //         payable(address(this))
    //     );
    //     assert(
    //         (feeManager.fee() * computedFee) / 10000 ==
    //             address(feeManager).balance - oldFeeManagerBalance
    //     );
    //     assert(
    //         token.balanceOf(address(account)) == 100 ether - 0x56bc75e2d630fffff
    //     );
    //     assert(
    //         token.balanceOf(0x690B9A9E9aa1C9dB991C7721a92d351Db4FaC990) ==
    //             0x56bc75e2d630fffff
    //     );
    // }

    receive() external payable {}
}
