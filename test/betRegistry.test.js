const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("BetRegistry", function () {
  let vault, registry, betRegistry, token;
  let admin, platform, creator, challenger, arbiter, stranger;
  let tokenAddress, vaultAddress, registryAddress, betRegistryAddress;

  const BET_MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BET_MANAGER_ROLE"));

  const STAKE = ethers.parseEther("1000");
  const ARBITER_FEE = ethers.parseEther("50");
  const PLATFORM_FEE = ethers.parseEther("50");
  const PAYOUT = ethers.parseEther("1900"); // stake*2 - arbiterFee - platformFee
  const ONE_DAY = 86400;

  const BetStatus = { OPEN: 0n, MATCHED: 1n, SETTLED: 2n, CANCELLED: 3n, FORFEITED: 4n };
  const BetType = { OPEN: 0n, PRIVATE: 1n };

  async function buildRequest(overrides = {}) {
    const deadline = (await time.latest()) + ONE_DAY;
    return {
      betType: BetType.OPEN,
      token: tokenAddress,
      arbiter: arbiter.address,
      challenger: ethers.ZeroAddress,
      stake: STAKE,
      arbiterFee: ARBITER_FEE,
      platformFee: PLATFORM_FEE,
      deadline,
      condition: "Test condition",
      ...overrides,
    };
  }

  async function createOpenBet(overrides = {}) {
    const request = await buildRequest(overrides);
    const tx = await betRegistry.connect(creator).createBet(request);
    const receipt = await tx.wait();
    const event = receipt.logs.find((l) => l.fragment?.name === "BetCreated");
    return { betId: event.args[0], request };
  }

  async function createMatchedBet(overrides = {}) {
    const { betId, request } = await createOpenBet(overrides);
    await betRegistry.connect(challenger).acceptBet(betId);
    return { betId, request };
  }

  beforeEach(async function () {
    [admin, platform, creator, challenger, arbiter, stranger] = await ethers.getSigners();

    token = await ethers.deployContract("Vbux", admin);
    tokenAddress = await token.getAddress();

    vault = await ethers.deployContract("UserVault", [admin.address], admin);
    vaultAddress = await vault.getAddress();

    registry = await ethers.deployContract("UserRegistry", [admin.address], admin);
    registryAddress = await registry.getAddress();

    betRegistry = await ethers.deployContract(
      "BetRegistry",
      [admin.address, platform.address, vaultAddress, registryAddress],
      admin
    );
    betRegistryAddress = await betRegistry.getAddress();

    // wire up: grant BET_MANAGER_ROLE to BetRegistry on both vault and registry
    await vault.connect(admin).grantRole(BET_MANAGER_ROLE, betRegistryAddress);
    await registry.connect(admin).grantRole(BET_MANAGER_ROLE, betRegistryAddress);

    // allow the token
    await vault.connect(admin).setTokenAllowed(tokenAddress, true);

    // register users
    await registry.connect(creator).register(ethers.encodeBytes32String("creator"));
    await registry.connect(challenger).register(ethers.encodeBytes32String("challenger"));
    await registry.connect(arbiter).register(ethers.encodeBytes32String("arbiter"));

    // fund users and deposit into vault
    const fund = async (signer) => {
      await token.connect(admin).transfer(signer.address, ethers.parseEther("10000"));
      await token.connect(signer).approve(vaultAddress, ethers.MaxUint256);
      await vault.connect(signer).deposit(tokenAddress, ethers.parseEther("5000"));
    };
    await fund(creator);
    await fund(challenger);
  });

  // ─── Deployment ────────────────────────────────────────────────────────────

  describe("Deployment", function () {
    it("stores vault, registry and platformAddress", async function () {
      expect(await betRegistry.vault()).to.equal(vaultAddress);
      expect(await betRegistry.registry()).to.equal(registryAddress);
      expect(await betRegistry.platformAddress()).to.equal(platform.address);
    });

    it("reverts with zero address arguments", async function () {
      await expect(
        ethers.deployContract("BetRegistry", [admin.address, ethers.ZeroAddress, vaultAddress, registryAddress], admin)
      ).to.be.revertedWith("Invalid platform address");
    });
  });

  // ─── createBet() ───────────────────────────────────────────────────────────

  describe("createBet()", function () {
    it("creates an OPEN bet and locks creator's stake", async function () {
      const { betId } = await createOpenBet();
      const bet = await betRegistry.getBet(betId);

      expect(bet.status).to.equal(BetStatus.OPEN);
      expect(bet.betType).to.equal(BetType.OPEN);
      expect(bet.creator).to.equal(creator.address);
      expect(bet.arbiter).to.equal(arbiter.address);
      expect(bet.stake).to.equal(STAKE);
      expect(bet.payout).to.equal(PAYOUT);
      expect(await betRegistry.getBetCount()).to.equal(1);
      expect(await vault.lockedBalance(creator.address, tokenAddress)).to.equal(STAKE);
      expect(await vault.availableBalance(creator.address, tokenAddress)).to.equal(
        ethers.parseEther("4000")
      );
    });

    it("creates a PRIVATE bet with designated challenger", async function () {
      const { betId } = await createOpenBet({
        betType: BetType.PRIVATE,
        challenger: challenger.address,
      });
      const bet = await betRegistry.getBet(betId);
      expect(bet.betType).to.equal(BetType.PRIVATE);
      expect(bet.challenger).to.equal(challenger.address);
    });

    it("derives payout on-chain (stake*2 - fees)", async function () {
      const { betId } = await createOpenBet({
        arbiterFee: ethers.parseEther("100"),
        platformFee: ethers.parseEther("100"),
      });
      const bet = await betRegistry.getBet(betId);
      expect(bet.payout).to.equal(ethers.parseEther("1800"));
    });

    it("emits BetCreated", async function () {
      const request = await buildRequest();
      await expect(betRegistry.connect(creator).createBet(request))
        .to.emit(betRegistry, "BetCreated")
        .withArgs(1n, creator.address, arbiter.address, tokenAddress, STAKE, BetType.OPEN);
    });

    it("increments betId sequentially", async function () {
      const { betId: id1 } = await createOpenBet();
      const { betId: id2 } = await createOpenBet();
      expect(id1).to.equal(1n);
      expect(id2).to.equal(2n);
    });

    it("reverts if creator is not registered", async function () {
      const request = await buildRequest();
      await expect(betRegistry.connect(stranger).createBet(request)).to.be.revertedWith(
        "Creator not registered"
      );
    });

    it("reverts if arbiter is not registered", async function () {
      const request = await buildRequest({ arbiter: stranger.address });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Arbiter not registered"
      );
    });

    it("reverts if arbiter is the creator", async function () {
      const request = await buildRequest({ arbiter: creator.address });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Arbiter cannot be creator"
      );
    });

    it("reverts if stake is zero", async function () {
      const request = await buildRequest({ stake: 0 });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Stake must be greater than 0"
      );
    });

    it("reverts if platform fee is zero", async function () {
      const request = await buildRequest({ platformFee: 0 });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Platform fee must be greater than 0"
      );
    });

    it("reverts if fees exceed total stake", async function () {
      const request = await buildRequest({
        arbiterFee: STAKE,
        platformFee: STAKE,
      });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Fees exceed total stake"
      );
    });

    it("reverts if token is not allowed", async function () {
      const otherToken = await ethers.deployContract("Vbux", admin);
      const request = await buildRequest({ token: await otherToken.getAddress() });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Token not allowed"
      );
    });

    it("reverts if deadline is in the past", async function () {
      const pastDeadline = (await time.latest()) - 1;
      const request = await buildRequest({ deadline: pastDeadline });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Deadline must be in the future"
      );
    });

    it("reverts for PRIVATE bet if challenger is not registered", async function () {
      const request = await buildRequest({
        betType: BetType.PRIVATE,
        challenger: stranger.address,
      });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Challenger not registered"
      );
    });

    it("reverts for PRIVATE bet if challenger is the creator", async function () {
      const request = await buildRequest({
        betType: BetType.PRIVATE,
        challenger: creator.address,
      });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Challenger cannot be creator"
      );
    });

    it("reverts for PRIVATE bet if challenger is the arbiter", async function () {
      const request = await buildRequest({
        betType: BetType.PRIVATE,
        challenger: arbiter.address,
      });
      await expect(betRegistry.connect(creator).createBet(request)).to.be.revertedWith(
        "Challenger cannot be arbiter"
      );
    });
  });

  // ─── acceptBet() ───────────────────────────────────────────────────────────

  describe("acceptBet()", function () {
    it("matches the bet and locks challenger's stake", async function () {
      const { betId } = await createOpenBet();
      await betRegistry.connect(challenger).acceptBet(betId);

      const bet = await betRegistry.getBet(betId);
      expect(bet.status).to.equal(BetStatus.MATCHED);
      expect(bet.challenger).to.equal(challenger.address);
      expect(await vault.lockedBalance(challenger.address, tokenAddress)).to.equal(STAKE);
    });

    it("emits BetMatched", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(challenger).acceptBet(betId))
        .to.emit(betRegistry, "BetMatched")
        .withArgs(betId, challenger.address);
    });

    it("allows any registered user to accept an OPEN bet", async function () {
      await registry.connect(stranger).register(ethers.encodeBytes32String("stranger"));
      await token.connect(admin).transfer(stranger.address, ethers.parseEther("2000"));
      await token.connect(stranger).approve(vaultAddress, ethers.MaxUint256);
      await vault.connect(stranger).deposit(tokenAddress, STAKE);

      const { betId } = await createOpenBet();
      await betRegistry.connect(stranger).acceptBet(betId);
      expect((await betRegistry.getBet(betId)).status).to.equal(BetStatus.MATCHED);
    });

    it("only allows the designated challenger for PRIVATE bets", async function () {
      const { betId } = await createOpenBet({
        betType: BetType.PRIVATE,
        challenger: challenger.address,
      });

      await registry.connect(stranger).register(ethers.encodeBytes32String("stranger"));
      await token.connect(admin).transfer(stranger.address, ethers.parseEther("2000"));
      await token.connect(stranger).approve(vaultAddress, ethers.MaxUint256);
      await vault.connect(stranger).deposit(tokenAddress, STAKE);

      await expect(betRegistry.connect(stranger).acceptBet(betId)).to.be.revertedWith(
        "Not the designated challenger"
      );
      await betRegistry.connect(challenger).acceptBet(betId);
      expect((await betRegistry.getBet(betId)).status).to.equal(BetStatus.MATCHED);
    });

    it("reverts if creator tries to accept own bet", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(creator).acceptBet(betId)).to.be.revertedWith(
        "Creator cannot accept own bet"
      );
    });

    it("reverts if arbiter tries to accept the bet", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(arbiter).acceptBet(betId)).to.be.revertedWith(
        "Arbiter cannot accept bet"
      );
    });

    it("reverts if the bet deadline has passed", async function () {
      const { betId } = await createOpenBet();
      await time.increase(ONE_DAY + 1);
      await expect(betRegistry.connect(challenger).acceptBet(betId)).to.be.revertedWith(
        "Bet deadline has passed"
      );
    });

    it("reverts if bet is already matched", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(challenger).acceptBet(betId)).to.be.revertedWith(
        "Bet is not open"
      );
    });

    it("reverts if challenger is not registered", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(stranger).acceptBet(betId)).to.be.revertedWith(
        "Challenger not registered"
      );
    });
  });

  // ─── declareWinner() ───────────────────────────────────────────────────────

  describe("declareWinner()", function () {
    it("settles when arbiter declares creator as winner", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(arbiter).declareWinner(betId, creator.address);

      const bet = await betRegistry.getBet(betId);
      expect(bet.status).to.equal(BetStatus.SETTLED);
      expect(bet.winner).to.equal(creator.address);

      expect(await vault.availableBalance(creator.address, tokenAddress)).to.equal(
        ethers.parseEther("4000") + PAYOUT
      );
      expect(await vault.availableBalance(arbiter.address, tokenAddress)).to.equal(ARBITER_FEE);
      expect(await vault.availableBalance(platform.address, tokenAddress)).to.equal(PLATFORM_FEE);
      expect(await vault.lockedBalance(creator.address, tokenAddress)).to.equal(0);
      expect(await vault.lockedBalance(challenger.address, tokenAddress)).to.equal(0);
    });

    it("settles when arbiter declares challenger as winner", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(arbiter).declareWinner(betId, challenger.address);

      expect(await vault.availableBalance(challenger.address, tokenAddress)).to.equal(
        ethers.parseEther("4000") + PAYOUT
      );
    });

    it("records win and loss in registry", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(arbiter).declareWinner(betId, creator.address);

      expect((await registry.getProfile(creator.address)).wins).to.equal(1);
      expect((await registry.getProfile(challenger.address)).losses).to.equal(1);
    });

    it("emits BetSettled", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(arbiter).declareWinner(betId, creator.address))
        .to.emit(betRegistry, "BetSettled")
        .withArgs(betId, creator.address, challenger.address, PAYOUT);
    });

    it("payout + arbiterFee + platformFee equals stake * 2", async function () {
      const { betId } = await createMatchedBet();
      const bet = await betRegistry.getBet(betId);
      expect(bet.payout + bet.arbiterFee + bet.platformFee).to.equal(STAKE * 2n);
    });

    it("reverts if caller is not the arbiter", async function () {
      const { betId } = await createMatchedBet();
      await expect(
        betRegistry.connect(creator).declareWinner(betId, creator.address)
      ).to.be.revertedWith("Only arbiter can declare winner");
    });

    it("reverts if bet is not matched", async function () {
      const { betId } = await createOpenBet();
      await expect(
        betRegistry.connect(arbiter).declareWinner(betId, creator.address)
      ).to.be.revertedWith("Bet is not matched");
    });

    it("reverts if winner is not a participant", async function () {
      const { betId } = await createMatchedBet();
      await expect(
        betRegistry.connect(arbiter).declareWinner(betId, stranger.address)
      ).to.be.revertedWith("Invalid winner");
    });

    it("reverts if the arbitration deadline has passed", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      await expect(
        betRegistry.connect(arbiter).declareWinner(betId, creator.address)
      ).to.be.revertedWith("Arbitration window has closed");
    });
  });

  // ─── cancel() ──────────────────────────────────────────────────────────────

  describe("cancel()", function () {
    it("cancels and unlocks creator's stake", async function () {
      const { betId } = await createOpenBet();
      await betRegistry.connect(creator).cancel(betId);

      expect((await betRegistry.getBet(betId)).status).to.equal(BetStatus.CANCELLED);
      expect(await vault.availableBalance(creator.address, tokenAddress)).to.equal(
        ethers.parseEther("5000")
      );
      expect(await vault.lockedBalance(creator.address, tokenAddress)).to.equal(0);
    });

    it("emits BetCancelled", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(creator).cancel(betId))
        .to.emit(betRegistry, "BetCancelled")
        .withArgs(betId, creator.address);
    });

    it("reverts if caller is not the creator", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(challenger).cancel(betId)).to.be.revertedWith(
        "Only creator can cancel"
      );
    });

    it("reverts if bet is already matched", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(creator).cancel(betId)).to.be.revertedWith(
        "Bet is not open"
      );
    });
  });

  // ─── forfeit() ─────────────────────────────────────────────────────────────

  describe("forfeit()", function () {
    it("creator forfeits — challenger wins payout + arbiterFee", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(creator).forfeit(betId);

      const bet = await betRegistry.getBet(betId);
      expect(bet.status).to.equal(BetStatus.FORFEITED);
      expect(bet.winner).to.equal(challenger.address);

      expect(await vault.availableBalance(challenger.address, tokenAddress)).to.equal(
        ethers.parseEther("4000") + PAYOUT + ARBITER_FEE
      );
      expect(await vault.availableBalance(platform.address, tokenAddress)).to.equal(PLATFORM_FEE);
      expect(await vault.lockedBalance(creator.address, tokenAddress)).to.equal(0);
      expect(await vault.lockedBalance(challenger.address, tokenAddress)).to.equal(0);
    });

    it("challenger forfeits — creator wins payout + arbiterFee", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(challenger).forfeit(betId);

      expect((await betRegistry.getBet(betId)).winner).to.equal(creator.address);
      expect(await vault.availableBalance(creator.address, tokenAddress)).to.equal(
        ethers.parseEther("4000") + PAYOUT + ARBITER_FEE
      );
    });

    it("forfeit payout + platformFee equals stake * 2", async function () {
      const { betId } = await createMatchedBet();
      const bet = await betRegistry.getBet(betId);
      expect(bet.payout + bet.arbiterFee + bet.platformFee).to.equal(STAKE * 2n);
    });

    it("records win and loss in registry", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(creator).forfeit(betId);

      expect((await registry.getProfile(challenger.address)).wins).to.equal(1);
      expect((await registry.getProfile(creator.address)).losses).to.equal(1);
    });

    it("emits BetForfeited", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(creator).forfeit(betId))
        .to.emit(betRegistry, "BetForfeited")
        .withArgs(betId, creator.address, challenger.address);
    });

    it("reverts if bet is not matched", async function () {
      const { betId } = await createOpenBet();
      await expect(betRegistry.connect(creator).forfeit(betId)).to.be.revertedWith(
        "Bet is not matched"
      );
    });

    it("reverts if caller is not a participant", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(stranger).forfeit(betId)).to.be.revertedWith(
        "Only participants can forfeit"
      );
    });

    it("reverts if arbiter tries to forfeit", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(arbiter).forfeit(betId)).to.be.revertedWith(
        "Only participants can forfeit"
      );
    });
  });

  // ─── claimTimeout() ────────────────────────────────────────────────────────

  describe("claimTimeout()", function () {
    it("refunds both participants minus 5% platform fee after deadline", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);

      await betRegistry.connect(creator).claimTimeout(betId);

      // Each participant staked 1000, fee = 50 (5%), refund = 950
      // available was 4000 after staking, now 4000 + 950 = 4950
      expect((await betRegistry.getBet(betId)).status).to.equal(BetStatus.CANCELLED);
      expect(await vault.availableBalance(creator.address, tokenAddress)).to.equal(
        ethers.parseEther("4950")
      );
      expect(await vault.availableBalance(challenger.address, tokenAddress)).to.equal(
        ethers.parseEther("4950")
      );
    });

    it("credits platform with 5% from each side (10% total)", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      await betRegistry.connect(creator).claimTimeout(betId);
      // fee = 50 per side, total = 100
      expect(await vault.availableBalance(platform.address, tokenAddress)).to.equal(
        ethers.parseEther("100")
      );
    });

    it("can be triggered by either participant", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      await betRegistry.connect(challenger).claimTimeout(betId);
      expect((await betRegistry.getBet(betId)).status).to.equal(BetStatus.CANCELLED);
    });

    it("emits BetRefunded", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      await expect(betRegistry.connect(creator).claimTimeout(betId))
        .to.emit(betRegistry, "BetRefunded")
        .withArgs(betId);
    });

    it("reverts before the deadline", async function () {
      const { betId } = await createMatchedBet();
      await expect(betRegistry.connect(creator).claimTimeout(betId)).to.be.revertedWith(
        "Deadline has not passed"
      );
    });

    it("reverts if bet is not matched", async function () {
      const { betId } = await createOpenBet();
      await time.increase(ONE_DAY + 1);
      await expect(betRegistry.connect(creator).claimTimeout(betId)).to.be.revertedWith(
        "Bet is not matched"
      );
    });

    it("can be triggered by anyone after deadline (permissionless)", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      await betRegistry.connect(stranger).claimTimeout(betId);
      expect((await betRegistry.getBet(betId)).status).to.equal(BetStatus.CANCELLED);
    });
  });

  // ─── batchClaimTimeout() ───────────────────────────────────────────────────

  describe("batchClaimTimeout()", function () {
    it("processes multiple expired bets in one call", async function () {
      const { betId: id1 } = await createMatchedBet();
      const { betId: id2 } = await createMatchedBet();
      const { betId: id3 } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);

      await betRegistry.connect(stranger).batchClaimTimeout([id1, id2, id3]);

      for (const id of [id1, id2, id3]) {
        expect((await betRegistry.getBet(id)).status).to.equal(BetStatus.CANCELLED);
      }
    });

    it("applies the 5% timeout fee for each processed bet", async function () {
      const { betId: id1 } = await createMatchedBet();
      const { betId: id2 } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);

      await betRegistry.connect(stranger).batchClaimTimeout([id1, id2]);

      // 2 bets × 100 tokens platform fee each = 200 total
      expect(await vault.availableBalance(platform.address, tokenAddress)).to.equal(
        ethers.parseEther("200")
      );
    });

    it("skips bets that are not matched", async function () {
      const { betId: openId } = await createOpenBet();
      const { betId: matchedId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);

      await betRegistry.connect(stranger).batchClaimTimeout([openId, matchedId]);

      expect((await betRegistry.getBet(openId)).status).to.equal(BetStatus.OPEN);
      expect((await betRegistry.getBet(matchedId)).status).to.equal(BetStatus.CANCELLED);
    });

    it("skips bets whose deadline has not passed", async function () {
      const { betId: earlyId } = await createMatchedBet();
      const { betId: expiredId } = await createMatchedBet({ deadline: (await time.latest()) + 10 });
      await time.increase(11);

      await betRegistry.connect(stranger).batchClaimTimeout([earlyId, expiredId]);

      expect((await betRegistry.getBet(earlyId)).status).to.equal(BetStatus.MATCHED);
      expect((await betRegistry.getBet(expiredId)).status).to.equal(BetStatus.CANCELLED);
    });

    it("emits BetRefunded for each processed bet", async function () {
      const { betId: id1 } = await createMatchedBet();
      const { betId: id2 } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);

      await expect(betRegistry.connect(stranger).batchClaimTimeout([id1, id2]))
        .to.emit(betRegistry, "BetRefunded").withArgs(id1)
        .and.to.emit(betRegistry, "BetRefunded").withArgs(id2);
    });

    it("reverts if batch size exceeds the limit of 50", async function () {
      const ids = Array.from({ length: 51 }, (_, i) => i + 1);
      await expect(
        betRegistry.connect(stranger).batchClaimTimeout(ids)
      ).to.be.revertedWith("Exceeds batch limit");
    });

    it("accepts exactly 50 ids without reverting", async function () {
      const ids = Array.from({ length: 50 }, (_, i) => i + 1);
      await expect(
        betRegistry.connect(stranger).batchClaimTimeout(ids)
      ).to.not.be.reverted;
    });

    it("decrements activeBetCount for each processed bet", async function () {
      const { betId: id1 } = await createMatchedBet();
      const { betId: id2 } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      expect(await betRegistry.getActiveBetCount()).to.equal(2);

      await betRegistry.connect(stranger).batchClaimTimeout([id1, id2]);
      expect(await betRegistry.getActiveBetCount()).to.equal(0);
    });
  });

  // ─── getActiveBetCount() ───────────────────────────────────────────────────

  describe("getActiveBetCount()", function () {
    it("starts at zero", async function () {
      expect(await betRegistry.getActiveBetCount()).to.equal(0);
    });

    it("increments when a bet is created", async function () {
      await createOpenBet();
      expect(await betRegistry.getActiveBetCount()).to.equal(1);
    });

    it("does not change when a bet is accepted (still active)", async function () {
      await createMatchedBet();
      expect(await betRegistry.getActiveBetCount()).to.equal(1);
    });

    it("decrements when creator cancels", async function () {
      const { betId } = await createOpenBet();
      await betRegistry.connect(creator).cancel(betId);
      expect(await betRegistry.getActiveBetCount()).to.equal(0);
    });

    it("decrements when arbiter declares winner", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(arbiter).declareWinner(betId, creator.address);
      expect(await betRegistry.getActiveBetCount()).to.equal(0);
    });

    it("decrements when a participant forfeits", async function () {
      const { betId } = await createMatchedBet();
      await betRegistry.connect(creator).forfeit(betId);
      expect(await betRegistry.getActiveBetCount()).to.equal(0);
    });

    it("decrements when timeout is claimed", async function () {
      const { betId } = await createMatchedBet();
      await time.increase(ONE_DAY + 1);
      await betRegistry.connect(creator).claimTimeout(betId);
      expect(await betRegistry.getActiveBetCount()).to.equal(0);
    });

    it("tracks multiple bets correctly", async function () {
      const { betId: id1 } = await createMatchedBet();
      await createMatchedBet();
      await createOpenBet();
      expect(await betRegistry.getActiveBetCount()).to.equal(3);

      await betRegistry.connect(arbiter).declareWinner(id1, creator.address);
      expect(await betRegistry.getActiveBetCount()).to.equal(2);
    });
  });

  // ─── setPlatformAddress() ──────────────────────────────────────────────────

  describe("setPlatformAddress()", function () {
    it("updates the platform address", async function () {
      await betRegistry.connect(admin).setPlatformAddress(stranger.address);
      expect(await betRegistry.platformAddress()).to.equal(stranger.address);
    });

    it("emits PlatformAddressUpdated", async function () {
      await expect(betRegistry.connect(admin).setPlatformAddress(stranger.address))
        .to.emit(betRegistry, "PlatformAddressUpdated")
        .withArgs(platform.address, stranger.address);
    });

    it("reverts if caller is not admin", async function () {
      await expect(
        betRegistry.connect(creator).setPlatformAddress(stranger.address)
      ).to.be.reverted;
    });

    it("reverts on zero address", async function () {
      await expect(
        betRegistry.connect(admin).setPlatformAddress(ethers.ZeroAddress)
      ).to.be.revertedWith("Zero address not allowed");
    });
  });
});
