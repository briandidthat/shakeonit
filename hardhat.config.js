require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("dotenv").config({ path: __dirname + "/.env" });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    currency: "USD",
    // L1: "eth",
    // L2: "base",
    coinmarketcap: process.env.CMC_API_KEY,
    L1Etherscan: process.env.ETHERSCAN_API_KEY,
    // L2Etherscan: process.env.BASESCAN_API_KEY,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 77,
          },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      gas: 2100000,
      gasPrice: 8365186212,
    },
  },
};
