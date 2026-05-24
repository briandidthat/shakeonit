require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("dotenv").config({ path: __dirname + "/.env" });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    currency: "USD",
    L1: "ethereum",
    L2: "base",
    coinmarketcap: process.env.CMC_API_KEY,
    L1Etherscan: process.env.ETHERSCAN_API_KEY,
    L2Etherscan: process.env.BASESCAN_API_KEY,
    // Direct endpoints: Basescan for L2 gas price, Etherscan V2 (chainid=1) for L1 base fee
    gasPriceApi: `https://api.basescan.org/api?module=proxy&action=eth_gasPrice&apikey=${process.env.BASESCAN_API_KEY}`,
    getBlockApi: `https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getBlockByNumber&tag=latest&boolean=false&apikey=${process.env.ETHERSCAN_API_KEY}`,
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
    },
    // for testnet
    "base-sepolia": {
      url: "https://sepolia.base.org",
      accounts: [process.env.WALLET_KEY],
    },
  },
  defaultNetwork: "hardhat",
};
