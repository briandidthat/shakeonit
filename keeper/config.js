require("dotenv").config();

const required = (key) => {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
};

module.exports = {
  rpcUrl: required("RPC_URL"),
  privateKey: required("KEEPER_PRIVATE_KEY"),
  betRegistryAddress: required("BET_REGISTRY_ADDRESS"),
  subgraphUrl: process.env.SUBGRAPH_URL || null,
  dryRun: process.env.DRY_RUN === "true",
  batchSize: 50,
};
