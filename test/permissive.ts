import { expect } from 'chai';
import { randomBytes } from 'ethers/lib/utils';
import { Wallet } from 'ethers/lib/index';
import hre, { ethers } from 'hardhat';
import { ENTRYPOINT } from './utils/constants';
import {
	generateCorrectOperation,
	hashPermission,
	setupAccount,
	computerPermissionMerkleTree,
} from './utils/fixtures';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
	CustomEntryPoint,
	PermissiveAccount,
	PermissiveAccount__factory,
	PermissivePaymaster,
	Token,
	Token__factory,
} from '../typechain-types';
import { UserOperationStruct } from '@account-abstraction/contracts';
import { Permission } from './utils/types';
let libConfig: { libraries: { AllowanceCalldata: string } };

before(async () => {
	const AllowanceCalldata = await hre.ethers.getContractFactory(
		'AllowanceCalldata'
	);
	const { address } = await AllowanceCalldata.deploy();

	libConfig = {
		libraries: {
			AllowanceCalldata: address,
		},
	};
});

describe('setOperatorPermissions', () => {
	it('should update permission hash, update fee and value and emit event', async () => {
		const Permissive = await hre.ethers.getContractFactory(
			'PermissiveAccount',
			libConfig
		);
		const account = await Permissive.deploy(ENTRYPOINT);
		const [operator, merkleRoot] = [
			Wallet.createRandom().address,
			randomBytes(32),
		];
		const tx = account.setOperatorPermissions(operator, merkleRoot, 5, 8);
		await expect(tx).not.reverted;
		await expect(tx)
			.emit(account, 'OperatorMutated')
			.withArgs(
				operator,
				'0x0000000000000000000000000000000000000000000000000000000000000000',
				merkleRoot
			);
	});
});

describe('Entrpoint', () => {
	it('deploy entrypoint', async () => {
		const Entrypoint = await hre.ethers.getContractFactory('CustomEntryPoint');
		await expect(Entrypoint.deploy()).not.reverted;
	});
});

describe('validation & execution', () => {
	let owner: SignerWithAddress, operator: SignerWithAddress;
	let entrypoint: CustomEntryPoint;
	let account: PermissiveAccount;
	let operation: UserOperationStruct;
	let Token: Token__factory;
	let usdc: Token;
	let Permissive: PermissiveAccount__factory;

	before(async () => {
		const Entrypoint = await hre.ethers.getContractFactory('CustomEntryPoint');
		entrypoint = await Entrypoint.deploy();
		Token = await ethers.getContractFactory('Token');
		Permissive = await hre.ethers.getContractFactory(
			'PermissiveAccount',
			libConfig
		);
	});

	beforeEach(async () => {
		const signers = await ethers.getSigners();
		owner = signers[0];
		operator = signers[1];
		account = await setupAccount(
			entrypoint.address,
			operator.address,
			owner,
			libConfig
		);
		operation = generateCorrectOperation(account, operator.address);
		operation.sender = account.address;
		const opHash = await entrypoint.getUserOpHash(operation);
		operation.signature = await operator.signMessage(
			ethers.utils.arrayify(opHash)
		);
		usdc = await Token.deploy('USD Coin', 'USDC');
		await usdc.mint();
		account = await Permissive.deploy(entrypoint.address);
		await usdc.transfer(account.address, ethers.utils.parseEther('50'));
		await owner.sendTransaction({
			value: ethers.utils.parseEther('1'),
			to: account.address,
		});
	});

	async function setPermissionAndExecute(
		permission: Permission,
		userOpExtension: Partial<UserOperationStruct> = {}
	) {
		const merkleRoot = '0x' + computerPermissionMerkleTree([permission]).root;
		await account.setOperatorPermissions(
			operator.address,
			merkleRoot,
			ethers.utils.parseEther('0.5'),
			ethers.utils.parseEther('0.5')
		);
		operation = generateCorrectOperation(account, operator.address);
		operation.callData = account.interface.encodeFunctionData('execute', [
			usdc.address,
			0,
			usdc.interface.encodeFunctionData('transfer', [
				operator.address,
				ethers.utils.parseEther('10'),
			]),
			permission,
			computerPermissionMerkleTree([permission])
				.tree.getProof(hashPermission(permission))
				.map((e) => `0x${e.data.toString('hex')}`),
		]);
		operation.sender = account.address;
		operation = {
			...operation,
			...userOpExtension,
		};
		const opHash = await entrypoint.getUserOpHash(operation);
		operation.signature = await operator.signMessage(
			ethers.utils.arrayify(opHash)
		);
		return entrypoint.handleOps([operation], account.address);
	}

	it('should transfer usdc', async () => {
		const permission = {
			operator: operator.address,
			to: usdc.address,
			selector: Token.interface.getSighash('transfer'),
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		};
		await setPermissionAndExecute(permission);
		expect(await usdc.balanceOf(owner.address)).to.be.eq(
			ethers.utils.parseUnits('50', 'ether')
		);
		expect(await usdc.balanceOf(account.address)).to.be.eq(
			ethers.utils.parseUnits('40', 'ether')
		);
		expect(await usdc.balanceOf(operator.address)).to.be.eq(
			ethers.utils.parseUnits('10', 'ether')
		);
	});

	describe('permission data tests', () => {
		it('should refuse because invalid operator', async () => {
			const permission = {
				operator: Wallet.createRandom().address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			};
			await expect(setPermissionAndExecute(permission)).to.reverted;
		});
		it('should refuse because invalid to', async () => {
			const permission = {
				operator: operator.address,
				to: Wallet.createRandom().address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			};
			await expect(setPermissionAndExecute(permission)).to.reverted;
		});
		it('should refuse because invalid selector', async () => {
			const permission = {
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('mint'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			};
			await expect(setPermissionAndExecute(permission)).to.reverted;
		});
		it('should refuse because invalid paymaster', async () => {
			const permission = {
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000001',
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			};
			await expect(setPermissionAndExecute(permission)).to.reverted;
		});
		it('should refuse because expired unix', async () => {
			const permission = {
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 3,
				expiresAtBlock: 0,
			};
			// execution does not revert, check usdc state if no change, it failed
			await setPermissionAndExecute(permission);
			expect(await usdc.balanceOf(owner.address)).to.be.eq(
				ethers.utils.parseUnits('50', 'ether')
			);
			expect(await usdc.balanceOf(account.address)).to.be.eq(
				ethers.utils.parseUnits('50', 'ether')
			);
			expect(await usdc.balanceOf(operator.address)).to.be.eq(
				ethers.utils.parseUnits('0', 'ether')
			);
		});
		it('should refuse because expired block', async () => {
			const permission = {
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 0,
				expiresAtBlock: 2,
			};
			// execution does not revert, check usdc state if no change, it failed
			await setPermissionAndExecute(permission);
			expect(await usdc.balanceOf(owner.address)).to.be.eq(
				ethers.utils.parseUnits('50', 'ether')
			);
			expect(await usdc.balanceOf(account.address)).to.be.eq(
				ethers.utils.parseUnits('50', 'ether')
			);
			expect(await usdc.balanceOf(operator.address)).to.be.eq(
				ethers.utils.parseUnits('0', 'ether')
			);
		});
	});

	describe('paymaster', () => {
		let paymaster: PermissivePaymaster;
		before(async () => {
			const Paymaster = await ethers.getContractFactory('PermissivePaymaster');
			const op = generateCorrectOperation(account, operator.address);
			paymaster = await Paymaster.deploy(
				`0x${'0'.repeat(40)}`,
				'USDT',
				entrypoint.address
			);
			await paymaster.deposit({
				value: ethers.utils.parseEther('1'),
			});
		});

		it('should refuse because not enough tokens on paymaster', async () => {
			const permission = {
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: paymaster.address,
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			};
			await expect(
				setPermissionAndExecute(permission, {
					paymasterAndData: paymaster.address,
				})
			)
				.to.be.revertedWithCustomError(entrypoint, 'FailedOp')
				.withArgs(0, paymaster.address, 'TokenPaymaster: no balance');
		});

		it('should success with paymaster', async () => {
			const op = generateCorrectOperation(account, operator.address);
			await paymaster.mintTokens(
				account.address,
				ethers.BigNumber.from(op.callGasLimit).mul(
					ethers.BigNumber.from(op.maxFeePerGas)
				)
			);
			const permission = {
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: paymaster.address,
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			};
			await setPermissionAndExecute(permission, {
				paymasterAndData: paymaster.address,
			});
		});
	});
});

describe('factory', () => {
	let entrypoint: CustomEntryPoint;
	let owner: SignerWithAddress;
	let operator: SignerWithAddress;

	before(async () => {
		const Entrypoint = await hre.ethers.getContractFactory('CustomEntryPoint');
		entrypoint = await Entrypoint.deploy();
		const signers = await ethers.getSigners();
		owner = signers[0];
		operator = signers[1];
	});

	it('should create account', async () => {
		const Factory = await ethers.getContractFactory(
			'PermissiveFactory',
			libConfig
		);
		const factory = await Factory.deploy(entrypoint.address);
		const account = new ethers.Contract(
			await factory.getAddress(
				owner.address,
				ethers.BigNumber.from(owner.address)
			),
			await (
				await ethers.getContractFactory('PermissiveAccount', libConfig)
			).interface
		);
		await entrypoint.depositTo(account.address, {
			value: ethers.utils.parseEther('1'),
		});
		let operation = generateCorrectOperation(account, operator.address);
		operation.callData = [];
		operation.sender = account.address;
		operation.preVerificationGas = '1000000';
		operation.callGasLimit = '1000000';
		operation.verificationGasLimit = '10000000';
		operation.initCode =
			factory.address +
			factory.interface
				.encodeFunctionData('createAccount', [
					owner.address,
					ethers.BigNumber.from(owner.address),
				])
				.slice(2);
		const opHash = await entrypoint.getUserOpHash(operation);
		operation.signature = await owner.signMessage(
			ethers.utils.arrayify(opHash)
		);
		return entrypoint.handleOps([operation], account.address);
	});
});
