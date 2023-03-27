import { getContractFactory } from '@nomiclabs/hardhat-ethers/types';
import { ethers } from 'hardhat';
import { config } from 'dotenv';
import abi from '../artifacts/@account-abstraction/contracts/core/EntryPoint.sol/EntryPoint.json';
import { abi as fAbi } from '../artifacts/contracts/core/PermissiveFactory.sol/PermissiveFactory.json';
import { generateCorrectOperation } from '../test/utils/fixtures';
import { estimateGas } from './utils/estimate_gas';
config();

async function main() {
	const owner = (await ethers.getSigners())[0];
	const factory = await ethers.getContractAt(
		'PermissiveFactory',
		process.env.FACTORY as string
	);
	const entrypoint = await ethers.getContractAt(
		'EntryPoint',
		process.env.ENTRYPOINT as string
	);

	const account = new ethers.Contract(
		await factory.getAddress(
			owner.address,
			ethers.BigNumber.from(owner.address)
		),
		await (
			await ethers.getContractFactory('PermissiveAccount')
		).interface
	);
	await entrypoint.depositTo(account.address, {
		value: ethers.utils.parseEther('0.5'),
	});
	let operation = generateCorrectOperation(account, owner.address);
	operation.callData = [];
	operation.sender = account.address;
	operation.initCode =
		factory.address +
		factory.interface
			.encodeFunctionData('createAccount', [
				owner.address,
				ethers.BigNumber.from(owner.address),
			])
			.slice(2);
	let opHash = await entrypoint.getUserOpHash(operation);
	operation.signature = await owner.signMessage(ethers.utils.arrayify(opHash));
	const gas = await estimateGas(operation);
	operation.maxFeePerGas = await (
		await ethers.provider.getGasPrice()
	).toString();
	operation.maxPriorityFeePerGas = '0';
	console.log(gas);
	operation.verificationGasLimit = gas.verificationGas;
	operation.preVerificationGas = gas.preVerificationGas;
	operation.callGasLimit = gas.callGasLimit;
	console.log(operation);
	opHash = await entrypoint.getUserOpHash(operation);
	operation.signature = await owner.signMessage(ethers.utils.arrayify(opHash));
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
