const { ethers } = require("hardhat");

/**
 * Deploys the full ShakeOnIt system.
 *
 * Environment variables:
 *   MULTISIG_ADDRESS   — address that will own ShakeOnIt (required on non-local networks)
 *   PLATFORM_ADDRESS   — address that receives platform fees (required on non-local networks)
 *   ALLOWED_TOKENS     — comma-separated list of token addresses to whitelist on deploy
 *
 * On local networks (hardhat/localhost) the deployer address is used as fallback.
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const isLocal = network.chainId === 31337n;

  console.log(`\nDeploying on ${network.name} (chainId: ${network.chainId})`);
  console.log(`Deployer: ${deployer.address}`);

  const multiSig = process.env.MULTISIG_ADDRESS ?? (isLocal ? deployer.address : null);
  const platform = process.env.PLATFORM_ADDRESS ?? (isLocal ? deployer.address : null);

  if (!multiSig || !platform) {
    throw new Error(
      "MULTISIG_ADDRESS and PLATFORM_ADDRESS must be set for non-local deployments."
    );
  }

  console.log(`MultiSig:         ${multiSig}`);
  console.log(`Platform address: ${platform}\n`);

  // ── Deploy ──────────────────────────────────────────────────────────────────

  console.log("Deploying ShakeOnIt (deploys UserVault, UserRegistry, BetRegistry internally)...");
  const ShakeOnIt = await ethers.getContractFactory("ShakeOnIt");
  const system = await ShakeOnIt.deploy(multiSig, platform);
  await system.waitForDeployment();

  const systemAddress = await system.getAddress();
  const vaultAddress = await system.userVault();
  const registryAddress = await system.userRegistry();
  const betRegistryAddress = await system.betRegistry();

  console.log("\n── Deployed addresses ──────────────────────────────────────");
  console.log(`ShakeOnIt:    ${systemAddress}`);
  console.log(`UserVault:    ${vaultAddress}`);
  console.log(`UserRegistry: ${registryAddress}`);
  console.log(`BetRegistry:  ${betRegistryAddress}`);

  // ── Allowlist tokens ───────────────────────────────────────────────────────

  const tokenList = process.env.ALLOWED_TOKENS
    ? process.env.ALLOWED_TOKENS.split(",").map((t) => t.trim()).filter(Boolean)
    : [];

  if (tokenList.length > 0) {
    console.log("\n── Allowing tokens ─────────────────────────────────────────");
    for (const token of tokenList) {
      await system.setTokenAllowed(token, true);
      console.log(`Allowed: ${token}`);
    }
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  console.log("\n── Deployment complete ─────────────────────────────────────");
  console.log("Next steps:");
  console.log("  1. Transfer ShakeOnIt ownership to your multisig if deployed from an EOA.");
  console.log("  2. Add tokens via: system.setTokenAllowed(tokenAddress, true)");
  console.log("  3. Users can now register via UserRegistry and deposit via UserVault.");

  return { systemAddress, vaultAddress, registryAddress, betRegistryAddress };
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
