import { ethers } from 'hardhat';
import { config } from 'dotenv';

config();

async function main() {
	const Factory = await ethers.getContractFactory('PermissiveFactory');
	const factory = await Factory.deploy(process.env.ENTRYPOINT as string);
	console.log(factory.address);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
