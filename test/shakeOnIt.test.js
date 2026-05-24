const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ShakeOnIt", function () {
  let system, token;
  let multiSig, platform, user, stranger;
  let vaultAddress, registryAddress, betRegistryAddress;

  const BET_MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BET_MANAGER_ROLE"));
  const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;

  beforeEach(async function () {
    [multiSig, platform, user, stranger] = await ethers.getSigners();

    system = await ethers.deployContract(
      "ShakeOnIt",
      [multiSig.address, platform.address],
      multiSig
    );

    token = await ethers.deployContract("Vbux", multiSig);

    vaultAddress = await system.userVault();
    registryAddress = await system.userRegistry();
    betRegistryAddress = await system.betRegistry();
  });

  // ─── Deployment ────────────────────────────────────────────────────────────

  describe("Deployment", function () {
    it("deploys all three sub-contracts", async function () {
      expect(vaultAddress).to.be.properAddress;
      expect(registryAddress).to.be.properAddress;
      expect(betRegistryAddress).to.be.properAddress;
    });

    it("sets multiSig as owner", async function () {
      expect(await system.owner()).to.equal(multiSig.address);
    });

    it("grants ShakeOnIt DEFAULT_ADMIN_ROLE on UserVault", async function () {
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      expect(await vault.hasRole(DEFAULT_ADMIN_ROLE, await system.getAddress())).to.be.true;
    });

    it("grants ShakeOnIt DEFAULT_ADMIN_ROLE on UserRegistry", async function () {
      const registry = await ethers.getContractAt("UserRegistry", registryAddress);
      expect(await registry.hasRole(DEFAULT_ADMIN_ROLE, await system.getAddress())).to.be.true;
    });

    it("grants BetRegistry BET_MANAGER_ROLE on UserVault", async function () {
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      expect(await vault.hasRole(BET_MANAGER_ROLE, betRegistryAddress)).to.be.true;
    });

    it("grants BetRegistry BET_MANAGER_ROLE on UserRegistry", async function () {
      const registry = await ethers.getContractAt("UserRegistry", registryAddress);
      expect(await registry.hasRole(BET_MANAGER_ROLE, betRegistryAddress)).to.be.true;
    });

    it("sets platform address on BetRegistry", async function () {
      const betRegistry = await ethers.getContractAt("BetRegistry", betRegistryAddress);
      expect(await betRegistry.platformAddress()).to.equal(platform.address);
    });

    it("emits SystemDeployed with all four values", async function () {
      const tx = system.deploymentTransaction();
      const receipt = await tx.wait();
      const iface = (await ethers.getContractFactory("ShakeOnIt")).interface;
      const log = receipt.logs.find(
        (l) => l.topics[0] === iface.getEvent("SystemDeployed").topicHash
      );
      expect(log).to.not.be.undefined;
    });

    it("reverts with zero multiSig address", async function () {
      // Ownable catches this before our constructor body runs.
      await expect(
        ethers.deployContract("ShakeOnIt", [ethers.ZeroAddress, platform.address], multiSig)
      ).to.be.revertedWithCustomError({ interface: (await ethers.getContractFactory("ShakeOnIt")).interface }, "OwnableInvalidOwner");
    });

    it("reverts with zero platform address", async function () {
      await expect(
        ethers.deployContract("ShakeOnIt", [multiSig.address, ethers.ZeroAddress], multiSig)
      ).to.be.revertedWith("Invalid platform address");
    });
  });

  // ─── upgradeBetRegistry() ──────────────────────────────────────────────────

  describe("upgradeBetRegistry()", function () {
    let newBetRegistry, newBetRegistryAddress, systemAddress;

    beforeEach(async function () {
      systemAddress = await system.getAddress();

      // Deploy a replacement BetRegistry with ShakeOnIt as admin.
      newBetRegistry = await ethers.deployContract(
        "BetRegistry",
        [systemAddress, platform.address, vaultAddress, registryAddress],
        multiSig
      );
      newBetRegistryAddress = await newBetRegistry.getAddress();
    });

    it("updates betRegistry pointer", async function () {
      await system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress);
      expect(await system.betRegistry()).to.equal(newBetRegistryAddress);
    });

    it("revokes BET_MANAGER_ROLE from old registry on UserVault", async function () {
      await system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress);
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      expect(await vault.hasRole(BET_MANAGER_ROLE, betRegistryAddress)).to.be.false;
    });

    it("revokes BET_MANAGER_ROLE from old registry on UserRegistry", async function () {
      await system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress);
      const registry = await ethers.getContractAt("UserRegistry", registryAddress);
      expect(await registry.hasRole(BET_MANAGER_ROLE, betRegistryAddress)).to.be.false;
    });

    it("grants BET_MANAGER_ROLE to new registry on UserVault", async function () {
      await system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress);
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      expect(await vault.hasRole(BET_MANAGER_ROLE, newBetRegistryAddress)).to.be.true;
    });

    it("grants BET_MANAGER_ROLE to new registry on UserRegistry", async function () {
      await system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress);
      const registry = await ethers.getContractAt("UserRegistry", registryAddress);
      expect(await registry.hasRole(BET_MANAGER_ROLE, newBetRegistryAddress)).to.be.true;
    });

    it("emits BetRegistryUpgraded", async function () {
      await expect(system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress))
        .to.emit(system, "BetRegistryUpgraded")
        .withArgs(betRegistryAddress, newBetRegistryAddress);
    });

    it("user funds remain safe in UserVault across an upgrade", async function () {
      // Deposit funds before upgrade
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      const tokenAddress = await token.getAddress();
      await system.connect(multiSig).setTokenAllowed(tokenAddress, true);
      await token.connect(multiSig).transfer(user.address, ethers.parseEther("1000"));
      await token.connect(user).approve(vaultAddress, ethers.MaxUint256);
      await vault.connect(user).deposit(tokenAddress, ethers.parseEther("1000"));

      // Upgrade
      await system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress);

      // Funds intact
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("1000")
      );
    });

    it("reverts if the current registry has active bets", async function () {
      // Wire up a token and two users so we can create a real bet on the system's BetRegistry.
      const tokenAddress = await token.getAddress();
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      const registry = await ethers.getContractAt("UserRegistry", registryAddress);
      const betReg = await ethers.getContractAt("BetRegistry", betRegistryAddress);
      const [, , creator, , arbiter] = await ethers.getSigners();

      await system.connect(multiSig).setTokenAllowed(tokenAddress, true);
      await registry.connect(creator).register(ethers.encodeBytes32String("creator2"));
      await registry.connect(arbiter).register(ethers.encodeBytes32String("arbiter2"));
      await token.connect(multiSig).transfer(creator.address, ethers.parseEther("1000"));
      await token.connect(creator).approve(vaultAddress, ethers.MaxUint256);
      await vault.connect(creator).deposit(tokenAddress, ethers.parseEther("1000"));

      const latest = await ethers.provider.getBlock("latest");
      await betReg.connect(creator).createBet({
        betType: 0,
        token: tokenAddress,
        arbiter: arbiter.address,
        challenger: ethers.ZeroAddress,
        stake: ethers.parseEther("500"),
        arbiterFee: ethers.parseEther("25"),
        platformFee: ethers.parseEther("25"),
        deadline: latest.timestamp + 86400,
        condition: "active bet",
      });

      await expect(
        system.connect(multiSig).upgradeBetRegistry(newBetRegistryAddress)
      ).to.be.revertedWith("Registry has active bets");
    });

    it("reverts if caller is not the owner", async function () {
      await expect(
        system.connect(stranger).upgradeBetRegistry(newBetRegistryAddress)
      ).to.be.revertedWithCustomError(system, "OwnableUnauthorizedAccount");
    });

    it("reverts on zero address", async function () {
      await expect(
        system.connect(multiSig).upgradeBetRegistry(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid address");
    });

    it("reverts if address is already the current registry", async function () {
      await expect(
        system.connect(multiSig).upgradeBetRegistry(betRegistryAddress)
      ).to.be.revertedWith("Already current registry");
    });
  });

  // ─── setTokenAllowed() ─────────────────────────────────────────────────────

  describe("setTokenAllowed()", function () {
    it("allows a token in UserVault", async function () {
      const tokenAddress = await token.getAddress();
      await system.connect(multiSig).setTokenAllowed(tokenAddress, true);

      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      expect(await vault.allowedTokens(tokenAddress)).to.be.true;
    });

    it("removes a token from the allowlist", async function () {
      const tokenAddress = await token.getAddress();
      await system.connect(multiSig).setTokenAllowed(tokenAddress, true);
      await system.connect(multiSig).setTokenAllowed(tokenAddress, false);

      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      expect(await vault.allowedTokens(tokenAddress)).to.be.false;
    });

    it("reverts if caller is not the owner", async function () {
      await expect(
        system.connect(stranger).setTokenAllowed(await token.getAddress(), true)
      ).to.be.revertedWithCustomError(system, "OwnableUnauthorizedAccount");
    });
  });

  // ─── setPlatformAddress() ──────────────────────────────────────────────────

  describe("setPlatformAddress()", function () {
    it("updates platform address on BetRegistry", async function () {
      await system.connect(multiSig).setPlatformAddress(stranger.address);
      const betRegistry = await ethers.getContractAt("BetRegistry", betRegistryAddress);
      expect(await betRegistry.platformAddress()).to.equal(stranger.address);
    });

    it("reverts if caller is not the owner", async function () {
      await expect(
        system.connect(stranger).setPlatformAddress(stranger.address)
      ).to.be.revertedWithCustomError(system, "OwnableUnauthorizedAccount");
    });
  });

  // ─── End-to-end through coordinator ────────────────────────────────────────

  describe("End-to-end via ShakeOnIt", function () {
    it("full bet lifecycle works through deployed contracts", async function () {
      const tokenAddress = await token.getAddress();
      const vault = await ethers.getContractAt("UserVault", vaultAddress);
      const registry = await ethers.getContractAt("UserRegistry", registryAddress);
      const betReg = await ethers.getContractAt("BetRegistry", betRegistryAddress);
      const [, , creator, challenger, arbiter] = await ethers.getSigners();

      // Allow token
      await system.connect(multiSig).setTokenAllowed(tokenAddress, true);

      // Register users
      await registry.connect(creator).register(ethers.encodeBytes32String("creator"));
      await registry.connect(challenger).register(ethers.encodeBytes32String("challenger"));
      await registry.connect(arbiter).register(ethers.encodeBytes32String("arbiter"));

      // Fund and deposit
      const fund = async (signer) => {
        await token.connect(multiSig).transfer(signer.address, ethers.parseEther("2000"));
        await token.connect(signer).approve(vaultAddress, ethers.MaxUint256);
        await vault.connect(signer).deposit(tokenAddress, ethers.parseEther("1000"));
      };
      await fund(creator);
      await fund(challenger);

      const latest = await ethers.provider.getBlock("latest");
      const deadline = latest.timestamp + 86400;

      // Create → accept → declare → balances correct
      const tx = await betReg.connect(creator).createBet({
        betType: 0,
        token: tokenAddress,
        arbiter: arbiter.address,
        challenger: ethers.ZeroAddress,
        stake: ethers.parseEther("500"),
        arbiterFee: ethers.parseEther("25"),
        platformFee: ethers.parseEther("25"),
        deadline,
        condition: "Who wins?",
      });
      const receipt = await tx.wait();
      const betId = receipt.logs.find((l) => l.fragment?.name === "BetCreated").args[0];

      await betReg.connect(challenger).acceptBet(betId);
      await betReg.connect(arbiter).declareWinner(betId, creator.address);

      // creator: started with 1000, staked 500, won 950 payout
      expect(await vault.availableBalance(creator.address, tokenAddress)).to.equal(
        ethers.parseEther("1450") // 500 remaining + 950 payout
      );
      expect(await vault.availableBalance(platform.address, tokenAddress)).to.equal(
        ethers.parseEther("25")
      );
      expect(await vault.availableBalance(arbiter.address, tokenAddress)).to.equal(
        ethers.parseEther("25")
      );

      // Withdraw to wallet
      const before = await token.balanceOf(creator.address);
      await vault.connect(creator).withdraw(tokenAddress, ethers.parseEther("1450"));
      expect(await token.balanceOf(creator.address)).to.equal(before + ethers.parseEther("1450"));
    });
  });
});
