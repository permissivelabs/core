// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/core/PermissionVerifier.sol";
import "../src/core/PermissionRegistry.sol";
import "../src/core/PermissionExecutor.sol";
import "account-abstraction/interfaces/UserOperation.sol";
import "account-abstraction/core/Helpers.sol";
import "./utils/Signature.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./mock/AlwaysFailingValidator.sol";
import "./mock/AlwaysTruthyValidator.sol";

contract VerifierTest is Test {
    using PermissionLib for Permission;
    using ECDSA for bytes32;

    PermissionRegistry registry;
    PermissionVerifier verifier;
    bytes32[] proofs;

    event PermissionVerified(bytes32 indexed userOpHash, UserOperation userOp);

    function setUp() public {
        registry = new PermissionRegistry();
        verifier = new PermissionVerifier(registry);
    }

    function testProof(
        UserOperation memory op,
        address dest,
        uint256 value,
        bytes calldata func,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        vm.assume(perm.to != dest);
        perm.operator = vm.addr(privateKey);
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            value,
            func,
            perm,
            proofs,
            gasFee
        );
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, bytes memory result) = callVerifier(op, hash);
        assert(success == false);
        assert(
            keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("InvalidTo")
                    )
                )
        );
    }

    function testTo(
        UserOperation memory op,
        address dest,
        uint256 value,
        bytes calldata func,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 1;
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            value,
            func,
            perm,
            proofs,
            gasFee
        );
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, bytes memory result) = callVerifier(op, hash);
        assert(success == false);
        assert(
            keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("OutOfPerms")
                    )
                )
        );
    }

    function testMaxUsage(
        UserOperation memory op,
        address dest,
        uint256 value,
        bytes calldata func,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 2;
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            value,
            func,
            perm,
            proofs,
            gasFee
        );
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, ) = callVerifier(op, hash);
        assert(success == false);
    }

    function testCallData(
        UserOperation memory op,
        address dest,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        vm.assume(perm.selector != ERC20.transfer.selector);
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 2;
        perm
            .allowed_arguments = hex"f851ca04880de0b6b3a7640001e202a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326e202a000000000000000000000000000000000000000000000000000000002e25208e3";
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            1 ether,
            bytes.concat(
                ERC20.transfer.selector,
                hex"f84b880de0b6b3a7640000a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
            ),
            perm,
            proofs,
            gasFee
        );
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, bytes memory result) = callVerifier(op, hash);
        assert(success == false);
        assert(
            keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("InvalidSelector")
                    )
                )
        );
    }

    function testSelector(
        UserOperation memory op,
        address dest,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        address paymaster = address(0);
        vm.assume(perm.paymaster != paymaster);
        vm.assume(gasFee < 100 ether);
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 2;
        perm.selector = ERC20.transfer.selector;
        perm
            .allowed_arguments = hex"f851ca04880de0b6b3a7640001e202a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326e202a000000000000000000000000000000000000000000000000000000002e25208e3";
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            1 ether,
            bytes.concat(
                ERC20.transfer.selector,
                hex"f84b880de0b6b3a7640000a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
            ),
            perm,
            proofs,
            gasFee
        );
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, bytes memory result) = callVerifier(op, hash);
        assert(success == false);
        assert(
            keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("InvalidPaymaster")
                    )
                )
        );
    }

    function testPaymaster(
        UserOperation memory op,
        address dest,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 2;
        perm.selector = ERC20.transfer.selector;
        perm.paymaster = address(bytes20(op.paymasterAndData));
        perm.dataValidator = address(new AlwaysFailingValidator());
        perm
            .allowed_arguments = hex"f851ca04880de0b6b3a7640001e202a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326e202a000000000000000000000000000000000000000000000000000000002e25208e3";
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            1 ether,
            bytes.concat(
                ERC20.transfer.selector,
                hex"f84b880de0b6b3a7640000a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
            ),
            perm,
            proofs,
            gasFee
        );
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, bytes memory result) = callVerifier(op, hash);
        assert(success == false);
        assert(
            keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("Invalid data")
                    )
                )
        );
    }

    function testValidator(
        UserOperation memory op,
        address dest,
        Permission memory perm,
        uint256 gasFee,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        try verifier.computeGasFee(op) returns (uint256) {} catch {
            vm.assume(false);
        }
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 2;
        perm.selector = ERC20.transfer.selector;
        perm.paymaster = address(bytes20(op.paymasterAndData));
        perm.dataValidator = address(new AlwaysTruthyValidator());
        perm
            .allowed_arguments = hex"f851ca04880de0b6b3a7640001e202a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326e202a000000000000000000000000000000000000000000000000000000002e25208e3";
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        op.callData = abi.encodeWithSelector(
            PermissionExecutor.execute.selector,
            dest,
            1 ether,
            bytes.concat(
                ERC20.transfer.selector,
                hex"f84b880de0b6b3a7640000a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
            ),
            perm,
            proofs,
            gasFee
        );
        vm.assume(gasFee != verifier.computeGasFee(op));
        bytes32 hash = UserOperationLib.hash(op);
        (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
        op.signature = abi.encodePacked(r, s, v);
        (bool success, bytes memory result) = callVerifier(op, hash);
        assert(success == false);
        assert(
            keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("Invalid provided fee")
                    )
                ) ||
                keccak256(result) ==
                keccak256(
                    abi.encodePacked(
                        bytes4(keccak256("Error(string)")),
                        abi.encode("Arithmetic over/underflow")
                    )
                )
        );
    }

    function testFee(
        UserOperation memory op,
        address dest,
        Permission memory perm,
        uint256 privateKey
    ) public {
        validPrivateKey(privateKey);
        vm.assume(perm.operator.code.length == 0);
        perm.operator = vm.addr(privateKey);
        perm.to = dest;
        perm.maxUsage = 2;
        perm.selector = ERC20.transfer.selector;
        perm.paymaster = address(bytes20(op.paymasterAndData));
        perm.dataValidator = address(new AlwaysTruthyValidator());
        perm.validAfter = 667;
        perm.validUntil = 999;
        perm
            .allowed_arguments = hex"f851ca04880de0b6b3a7640001e202a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326e202a000000000000000000000000000000000000000000000000000000002e25208e3";
        bytes32 root = keccak256(bytes.concat(perm.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, root);
        registry.setOperatorPermissions(vm.addr(privateKey), root);
        try verifier.computeGasFee(op) returns (uint256 gasFee) {
            op.callData = abi.encodeWithSelector(
                PermissionExecutor.execute.selector,
                dest,
                1 ether,
                bytes.concat(
                    ERC20.transfer.selector,
                    hex"f84b880de0b6b3a7640000a00000000000000000000000001f9090aae28b8a3dceadf281b0f12828e676c326a000000000000000000000000000000000000000000000000000000002e25208e3"
                ),
                perm,
                proofs,
                gasFee
            );
            bytes32 hash = UserOperationLib.hash(op);
            (v, r, s) = vm.sign(privateKey, hash.toEthSignedMessageHash());
            op.signature = abi.encodePacked(r, s, v);
            vm.expectEmit(true, false, false, true, address(this));
            emit PermissionVerified(hash, op);
            (bool success, bytes memory result) = callVerifier(op, hash);
            if (success == false) {
                assert(
                    keccak256(result) ==
                        keccak256(
                            abi.encodePacked(
                                bytes4(keccak256("Error(string)")),
                                abi.encode("Arithmetic over/underflow")
                            )
                        )
                );
            } else {
                assert(
                    registry.remainingPermUsage(address(this), perm.hash()) == 1
                );
                ValidationData memory validationData = _parseValidationData(
                    uint256(bytes32(result))
                );
                assert(validationData.validAfter == perm.validAfter);
                assert(validationData.validUntil == perm.validUntil);
                assert(validationData.aggregator == address(0));
            }
        } catch {
            vm.assume(false);
        }
    }

    function validPrivateKey(uint256 privateKey) internal pure {
        vm.assume(
            privateKey <
                115792089237316195423570985008687907852837564279074904382605163141518161494337 &&
                privateKey != 0
        );
    }

    function callVerifier(
        UserOperation memory op,
        bytes32 hash
    ) internal returns (bool success, bytes memory result) {
        (success, result) = address(verifier).delegatecall(
            abi.encodeWithSelector(verifier.verify.selector, op, hash, 0)
        );
    }
}
