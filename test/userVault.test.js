const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UserVault", function () {
  let vault, token;
  let admin, betRegistry, user, other;
  let tokenAddress, vaultAddress;

  const BET_MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BET_MANAGER_ROLE"));
  const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;

  const deposit = (signer, amount) =>
    vault.connect(signer).deposit(tokenAddress, ethers.parseEther(amount));

  beforeEach(async function () {
    [admin, betRegistry, user, other] = await ethers.getSigners();

    token = await ethers.deployContract("Vbux", admin);
    tokenAddress = await token.getAddress();

    vault = await ethers.deployContract("UserVault", [admin.address], admin);
    vaultAddress = await vault.getAddress();

    // whitelist the token and grant BET_MANAGER_ROLE to the mock bet registry
    await vault.connect(admin).setTokenAllowed(tokenAddress, true);
    await vault.connect(admin).grantRole(BET_MANAGER_ROLE, betRegistry.address);

    // fund the user
    await token.connect(admin).transfer(user.address, ethers.parseEther("10000"));
    // approve the vault
    await token.connect(user).approve(vaultAddress, ethers.MaxUint256);
  });

  describe("Deployment", function () {
    it("grants DEFAULT_ADMIN_ROLE to deployer", async function () {
      expect(await vault.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
    });

    it("token is allowed after setTokenAllowed", async function () {
      expect(await vault.allowedTokens(tokenAddress)).to.be.true;
    });
  });

  describe("deposit()", function () {
    it("increases available balance", async function () {
      await deposit(user, "1000");
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("1000")
      );
    });

    it("transfers tokens into the vault", async function () {
      await deposit(user, "1000");
      expect(await token.balanceOf(vaultAddress)).to.equal(ethers.parseEther("1000"));
    });

    it("emits Deposited", async function () {
      await expect(deposit(user, "500"))
        .to.emit(vault, "Deposited")
        .withArgs(user.address, tokenAddress, ethers.parseEther("500"));
    });

    it("reverts on disallowed token", async function () {
      const other20 = await ethers.deployContract("Vbux", admin);
      await expect(
        vault.connect(user).deposit(await other20.getAddress(), ethers.parseEther("1"))
      ).to.be.revertedWith("Token not allowed");
    });

    it("reverts on zero amount", async function () {
      await expect(vault.connect(user).deposit(tokenAddress, 0)).to.be.revertedWith(
        "Amount must be greater than 0"
      );
    });
  });

  describe("withdraw()", function () {
    beforeEach(async function () {
      await deposit(user, "1000");
    });

    it("decreases available balance and sends tokens", async function () {
      const before = await token.balanceOf(user.address);
      await vault.connect(user).withdraw(tokenAddress, ethers.parseEther("400"));
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("600")
      );
      expect(await token.balanceOf(user.address)).to.equal(before + ethers.parseEther("400"));
    });

    it("emits Withdrawn", async function () {
      await expect(vault.connect(user).withdraw(tokenAddress, ethers.parseEther("200")))
        .to.emit(vault, "Withdrawn")
        .withArgs(user.address, tokenAddress, ethers.parseEther("200"));
    });

    it("reverts when withdrawing more than available", async function () {
      await expect(
        vault.connect(user).withdraw(tokenAddress, ethers.parseEther("9999"))
      ).to.be.revertedWith("Insufficient available balance");
    });

    it("cannot withdraw locked funds", async function () {
      await vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("1000"));
      await expect(
        vault.connect(user).withdraw(tokenAddress, ethers.parseEther("1"))
      ).to.be.revertedWith("Insufficient available balance");
    });
  });

  describe("lock()", function () {
    beforeEach(async function () {
      await deposit(user, "1000");
    });

    it("moves available to locked", async function () {
      await vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("400"));
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("600")
      );
      expect(await vault.lockedBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("400")
      );
    });

    it("emits Locked", async function () {
      await expect(
        vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("100"))
      )
        .to.emit(vault, "Locked")
        .withArgs(user.address, tokenAddress, ethers.parseEther("100"));
    });

    it("reverts if not BET_MANAGER_ROLE", async function () {
      await expect(
        vault.connect(other).lock(user.address, tokenAddress, ethers.parseEther("100"))
      ).to.be.reverted;
    });

    it("reverts when locking more than available", async function () {
      await expect(
        vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("9999"))
      ).to.be.revertedWith("Insufficient available balance");
    });
  });

  describe("unlock()", function () {
    beforeEach(async function () {
      await deposit(user, "1000");
      await vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("600"));
    });

    it("moves locked back to available", async function () {
      await vault.connect(betRegistry).unlock(user.address, tokenAddress, ethers.parseEther("600"));
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("1000")
      );
      expect(await vault.lockedBalance(user.address, tokenAddress)).to.equal(0);
    });

    it("emits Unlocked", async function () {
      await expect(
        vault.connect(betRegistry).unlock(user.address, tokenAddress, ethers.parseEther("300"))
      )
        .to.emit(vault, "Unlocked")
        .withArgs(user.address, tokenAddress, ethers.parseEther("300"));
    });

    it("reverts when unlocking more than locked", async function () {
      await expect(
        vault.connect(betRegistry).unlock(user.address, tokenAddress, ethers.parseEther("9999"))
      ).to.be.revertedWith("Insufficient locked balance");
    });
  });

  describe("debit()", function () {
    beforeEach(async function () {
      await deposit(user, "1000");
      await vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("1000"));
    });

    it("removes from locked without returning to available", async function () {
      await vault.connect(betRegistry).debit(user.address, tokenAddress, ethers.parseEther("1000"));
      expect(await vault.lockedBalance(user.address, tokenAddress)).to.equal(0);
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(0);
    });

    it("emits Debited", async function () {
      await expect(
        vault.connect(betRegistry).debit(user.address, tokenAddress, ethers.parseEther("500"))
      )
        .to.emit(vault, "Debited")
        .withArgs(user.address, tokenAddress, ethers.parseEther("500"));
    });

    it("reverts when debiting more than locked", async function () {
      await expect(
        vault.connect(betRegistry).debit(user.address, tokenAddress, ethers.parseEther("9999"))
      ).to.be.revertedWith("Insufficient locked balance");
    });
  });

  describe("credit()", function () {
    it("adds to available balance without a deposit", async function () {
      await vault.connect(betRegistry).credit(user.address, tokenAddress, ethers.parseEther("500"));
      expect(await vault.availableBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("500")
      );
    });

    it("emits Credited", async function () {
      await expect(
        vault.connect(betRegistry).credit(user.address, tokenAddress, ethers.parseEther("200"))
      )
        .to.emit(vault, "Credited")
        .withArgs(user.address, tokenAddress, ethers.parseEther("200"));
    });

    it("reverts if not BET_MANAGER_ROLE", async function () {
      await expect(
        vault.connect(other).credit(user.address, tokenAddress, ethers.parseEther("100"))
      ).to.be.reverted;
    });
  });

  describe("totalBalance()", function () {
    it("returns sum of available and locked", async function () {
      await deposit(user, "1000");
      await vault.connect(betRegistry).lock(user.address, tokenAddress, ethers.parseEther("300"));
      expect(await vault.totalBalance(user.address, tokenAddress)).to.equal(
        ethers.parseEther("1000")
      );
    });
  });

  describe("setTokenAllowed()", function () {
    it("reverts if called by non-admin", async function () {
      await expect(vault.connect(user).setTokenAllowed(tokenAddress, false)).to.be.reverted;
    });

    it("emits TokenAllowlistUpdated", async function () {
      await expect(vault.connect(admin).setTokenAllowed(tokenAddress, false))
        .to.emit(vault, "TokenAllowlistUpdated")
        .withArgs(tokenAddress, false);
    });
  });
});
