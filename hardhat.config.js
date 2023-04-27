/** @type import('hardhat/config').HardhatUserConfig */

require("@nomicfoundation/hardhat-foundry");
require("xdeployer");
require("dotenv").config();

module.exports = {
  solidity: "0.8.18",
  xdeploy: {
    contract: 'PermissiveFactory',
    salt: process.env.SALT,
    constructorArgsPath: "./deploy-args/factory.ts",
    signer: process.env.PRIVATE_KEY,
    gasLimit: 15000000,
    networks: [
      // "mumbai",
      "baseTestnet",
      // "goerli",
      // "optimismTestnet",
      // "arbitrumTestnet"
    ],
    rpcUrls: [
      // process.env.RPC_80001,
      process.env.RPC_84531,
      // process.env.RPC_5,
      // process.env.RPC_420,
      // process.env.RPC_421613
    ]
  }
};
