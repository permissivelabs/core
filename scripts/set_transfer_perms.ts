import { getContractFactory } from '@nomiclabs/hardhat-ethers/types';
import { ethers } from 'hardhat';
import { config } from 'dotenv';
import abi from '../artifacts/@account-abstraction/contracts/core/EntryPoint.sol/EntryPoint.json';
import { abi as fAbi } from '../artifacts/contracts/core/PermissiveFactory.sol/PermissiveFactory.json';
import {
	computerPermissionMerkleTree,
	generateCorrectOperation,
	hashPermission,
} from '../test/utils/fixtures';
import { estimateGas } from './utils/estimate_gas';
config();

async function main() {
	const owner = (await ethers.getSigners())[0];
	const operator = (await ethers.getSigners())[1];
	const factory = await ethers.getContractAt(
		'PermissiveFactory',
		process.env.FACTORY as string
	);
	const account = await ethers.getContractAt(
		'PermissiveAccount',
		await factory.getAddress(owner.address, owner.address)
	);
	const permission = {
		operator: operator.address,
		to: operator.address,
		selector: '0x00000000',
		paymaster: '0x0000000000000000000000000000000000000000',
		expiresAtUnix: 1709933133,
		expiresAtBlock: 0,
	};
	const tree = computerPermissionMerkleTree([permission]);
	console.log(
		await account.setOperatorPermissions(
			permission.operator,
			'0x' + tree.root,
			ethers.utils.parseEther('0.5'),
			ethers.utils.parseEther('0.5')
		)
	);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
