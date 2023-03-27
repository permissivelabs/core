import { UserOperationStruct } from '@account-abstraction/contracts';

export const estimateGas = async (operation: UserOperationStruct) => {
	const data = await (
		await fetch(process.env.BUNDLER as string, {
			method: 'POST',
			body: JSON.stringify({
				jsonrpc: '2.0',
				id: 1,
				method: 'eth_estimateUserOperationGas',
				params: [operation, process.env.ENTRYPOINT],
			}),
		})
	).json();
	return data.result;
};
