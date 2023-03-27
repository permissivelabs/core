import { Contract, Signer, Wallet } from 'ethers';
import { defaultAbiCoder, keccak256, randomBytes } from 'ethers/lib/utils';
import { ethers } from 'hardhat';
import { Permission, ZPermission } from './types';
import { MerkleTree } from 'merkletreejs';
import hre from 'hardhat';
import { UserOperationStruct } from '@account-abstraction/contracts';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

export const permissionsSample = (operator: string): Permission[] => {
	return [
		{
			operator,
			to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
			selector: '0xa9059cbb', // erc20 transfer
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		},
		{
			operator,
			to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
			selector: '0xab790ba3', // erc721 transfer
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		},
		{
			operator,
			to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
			selector: '0x022c0d9f', // swap uniswap
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		},
	].map((p) => ZPermission.parse(p));
};

export const hashPermission = (permission: Permission): string => {
	return keccak256(
		defaultAbiCoder.encode(
			['address', 'address', 'bytes4', 'address', 'uint256', 'uint256'],
			Object.values(permission)
		)
	);
};

export const computerPermissionMerkleTree = (permissions: Permission[]) => {
	const leaves = permissions.map((p) => hashPermission(p));
	const tree = new MerkleTree(leaves, keccak256, {
		sortLeaves: true,
	});
	const root = tree.getRoot().toString('hex');
	return {
		tree,
		root,
	};
};

export const generateCorrectOperation = (
	account: Contract,
	operator: string
) => {
	const operation: UserOperationStruct = {
		sender: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
		nonce: 1,
		initCode: [],
		callData: account.interface.encodeFunctionData('execute', [
			'0x0576a174D229E3cFA37253523E645A78A0C91B57',
			4,
			permissionsSample(operator)[0].selector +
				ethers.utils.defaultAbiCoder
					.encode(
						['uint256', 'address'],
						[100, '0x0576a174D229E3cFA37253523E645A78A0C91B57']
					)
					.slice(2),
			permissionsSample(operator)[0],
			computerPermissionMerkleTree(permissionsSample(operator))
				.tree.getProof(hashPermission(permissionsSample(operator)[0]))
				.map((e) => `0x${e.data.toString('hex')}`),
		]),
		callGasLimit: '10000000',
		verificationGasLimit: '10000000',
		preVerificationGas: '10000',
		maxFeePerGas: '10000',
		maxPriorityFeePerGas: '10000',
		paymasterAndData: [],
		signature: [],
	};

	return operation;
};

export const setupAccount = async (
	ENTRYPOINT: string,
	operator: string,
	owner: SignerWithAddress
) => {
	const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
	const account = await Permissive.deploy(ENTRYPOINT);
	const merkleRoot =
		'0x' + computerPermissionMerkleTree(permissionsSample(operator)).root;
	await account.setOperatorPermissions(
		operator,
		merkleRoot,
		ethers.utils.parseEther('0.5'),
		ethers.utils.parseEther('0.5')
	);
	await owner.sendTransaction({
		value: ethers.utils.parseEther('1'),
		to: account.address,
	});
	return account;
};
