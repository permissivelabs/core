# # deploy mumbai
# forge script --rpc-url $RPC_80001 --broadcast --sender $OWNER ./scripts/Deploy.s.sol
# # base goerli
# forge script --rpc-url $RPC_84531 --broadcast --sender $OWNER ./scripts/DeploySafe.s.sol
# # linea goerli
# forge script --rpc-url $RPC_59140 --broadcast --sender $OWNER ./scripts/Deploy.s.sol
# # optimism goerli
# forge script --rpc-url $RPC_420 --broadcast --sender $OWNER ./scripts/Deploy.s.sol
# # arbitrum goerli
# forge script --rpc-url $RPC_421613 --broadcast --sender $OWNER ./scripts/Deploy.s.sol
# goerli
forge script --rpc-url $RPC_5 --broadcast --sender $OWNER ./scripts/DeploySafe.s.sol