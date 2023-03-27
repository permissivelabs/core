import { ethers } from 'hardhat';
import { z } from 'zod';

export const ZPermission = z.object({
	operator: z.string().length(42).startsWith('0x'),
	to: z.string().length(42).startsWith('0x'),
	selector: z.string().length(10).startsWith('0x'),
	paymaster: z.string().length(42).startsWith('0x'),
	expiresAtUnix: z.instanceof(ethers.BigNumber).or(z.number()),
	expiresAtBlock: z.instanceof(ethers.BigNumber).or(z.number()),
});

export type Permission = z.infer<typeof ZPermission>;
