import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-preprocessor';
import fs from 'fs';
import { config as dConfig } from 'dotenv';

dConfig();

const config: HardhatUserConfig = {
	preprocess: {
		eachLine: (hre) => ({
			transform: (line: string) => {
				if (line.match(/^\s*import /i)) {
					for (const [from, to] of getRemappings()) {
						if (line.includes(from)) {
							line = line.replace(from, to);
							break;
						}
					}
				}
				return line;
			},
		}),
	},
	defaultNetwork: 'hardhat',
	networks: {
		hardhat: {},
		mumbai: {
			url: process.env.RPC,
			accounts: [
				process.env.PRIVATE_KEY as string,
				process.env.PRIVATE_KEY2 as string,
			],
		},
		goerli: {
			url: process.env.GOERLI_URL || '',
			accounts: [
				process.env.PRIVATE_KEY as string,
				process.env.PRIVATE_KEY2 as string,
			],
		},
		sepolia: {
			url: process.env.SEPOLIA_URL || '',
			accounts: [
				process.env.PRIVATE_KEY as string,
				process.env.PRIVATE_KEY2 as string,
			],
		},
	},
	solidity: {
		version: '0.8.18',
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	paths: {
		sources: './src',
		cache: './cache_hardhat',
		tests: './test',
	},
	mocha: {
		timeout: 40000,
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN,
	},
};

function getRemappings() {
	return fs
		.readFileSync('remappings.txt', 'utf8')
		.split('\n')
		.filter(Boolean) // remove empty lines
		.map((line) => line.trim().split('='));
}

export default config;
