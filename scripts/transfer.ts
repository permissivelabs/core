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
	const entrypoint = await ethers.getContractAt(
		'EntryPoint',
		process.env.ENTRYPOINT as string
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
	let operation = generateCorrectOperation(account, operator.address);
	operation.callData = account.interface.encodeFunctionData('execute', [
		operator.address,
		ethers.utils.parseEther('0.3'),
		[],
		permission,
		computerPermissionMerkleTree([permission])
			.tree.getProof(hashPermission(permission))
			.map((e) => `0x${e.data.toString('hex')}`),
	]);
	operation.sender = account.address;
	let opHash = await entrypoint.getUserOpHash(operation);
	operation.signature = await operator.signMessage(
		ethers.utils.arrayify(opHash)
	);
	const gas = await estimateGas(operation);
	operation = {
		...operation,
		...gas,
	};
	opHash = await entrypoint.getUserOpHash(operation);
	operation.signature = await operator.signMessage(
		ethers.utils.arrayify(opHash)
	);
	console.log(
		await (
			await fetch(process.env.BUNDLER as string, {
				method: 'POST',
				body: JSON.stringify({
					jsonrpc: '2.0',
					id: 1,
					method: 'eth_sendUserOperation',
					params: [operation, process.env.ENTRYPOINT],
				}),
			})
		).json()
	);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
