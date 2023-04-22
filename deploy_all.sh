# deploy mumbai
forge script --rpc-url $RPC_80001 --broadcast --sender 0x490b97230d82c22b563c3f322470f643b305884e ./scripts/Deploy.s.sol
# base goerli
forge script --rpc-url $RPC_84531 --broadcast --sender 0x490b97230d82c22b563c3f322470f643b305884e ./scripts/Deploy.s.sol
# optimism goerli
forge script --rpc-url $RPC_420 --broadcast --sender 0x490b97230d82c22b563c3f322470f643b305884e ./scripts/Deploy.s.sol
# arbitrum goerli
forge script --rpc-url $RPC_421613 --broadcast --sender 0x490b97230d82c22b563c3f322470f643b305884e ./scripts/Deploy.s.sol
# goerli
forge script --rpc-url $RPC_5 --broadcast --sender 0x490b97230d82c22b563c3f322470f643b305884e ./scripts/Deploy.s.sol