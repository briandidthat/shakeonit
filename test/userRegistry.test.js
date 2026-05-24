const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UserRegistry", function () {
  let registry;
  let admin, betRegistry, user, other;

  const BET_MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BET_MANAGER_ROLE"));

  const username = ethers.encodeBytes32String("alice");
  const username2 = ethers.encodeBytes32String("bob");

  beforeEach(async function () {
    [admin, betRegistry, user, other] = await ethers.getSigners();
    registry = await ethers.deployContract("UserRegistry", [admin.address], admin);
    await registry.connect(admin).grantRole(BET_MANAGER_ROLE, betRegistry.address);
  });

  describe("register()", function () {
    it("registers a new user and stores their profile", async function () {
      await registry.connect(user).register(username);
      const profile = await registry.getProfile(user.address);
      expect(profile.username).to.equal(username);
      expect(profile.wins).to.equal(0);
      expect(profile.losses).to.equal(0);
    });

    it("marks the user as registered", async function () {
      await registry.connect(user).register(username);
      expect(await registry.isRegistered(user.address)).to.be.true;
    });

    it("records username ownership", async function () {
      await registry.connect(user).register(username);
      expect(await registry.usernameOwner(username)).to.equal(user.address);
    });

    it("emits UserRegistered", async function () {
      await expect(registry.connect(user).register(username))
        .to.emit(registry, "UserRegistered")
        .withArgs(user.address, username);
    });

    it("reverts if user is already registered", async function () {
      await registry.connect(user).register(username);
      await expect(registry.connect(user).register(username2)).to.be.revertedWith(
        "Already registered"
      );
    });

    it("reverts if username is already taken by another address", async function () {
      await registry.connect(user).register(username);
      await expect(registry.connect(other).register(username)).to.be.revertedWith(
        "Username already taken"
      );
    });

    it("reverts on empty username", async function () {
      await expect(registry.connect(user).register(ethers.ZeroHash)).to.be.revertedWith(
        "Username cannot be empty"
      );
    });

    it("allows two different users to register different usernames", async function () {
      await registry.connect(user).register(username);
      await registry.connect(other).register(username2);
      expect(await registry.isRegistered(user.address)).to.be.true;
      expect(await registry.isRegistered(other.address)).to.be.true;
    });
  });

  describe("recordWin()", function () {
    beforeEach(async function () {
      await registry.connect(user).register(username);
    });

    it("increments wins", async function () {
      await registry.connect(betRegistry).recordWin(user.address);
      const profile = await registry.getProfile(user.address);
      expect(profile.wins).to.equal(1);
    });

    it("emits WinRecorded with updated total", async function () {
      await expect(registry.connect(betRegistry).recordWin(user.address))
        .to.emit(registry, "WinRecorded")
        .withArgs(user.address, 1);
    });

    it("accumulates across multiple wins", async function () {
      await registry.connect(betRegistry).recordWin(user.address);
      await registry.connect(betRegistry).recordWin(user.address);
      await registry.connect(betRegistry).recordWin(user.address);
      expect((await registry.getProfile(user.address)).wins).to.equal(3);
    });

    it("reverts if caller lacks BET_MANAGER_ROLE", async function () {
      await expect(registry.connect(other).recordWin(user.address)).to.be.reverted;
    });

    it("reverts if user is not registered", async function () {
      await expect(
        registry.connect(betRegistry).recordWin(other.address)
      ).to.be.revertedWith("User not registered");
    });
  });

  describe("recordLoss()", function () {
    beforeEach(async function () {
      await registry.connect(user).register(username);
    });

    it("increments losses", async function () {
      await registry.connect(betRegistry).recordLoss(user.address);
      const profile = await registry.getProfile(user.address);
      expect(profile.losses).to.equal(1);
    });

    it("emits LossRecorded with updated total", async function () {
      await expect(registry.connect(betRegistry).recordLoss(user.address))
        .to.emit(registry, "LossRecorded")
        .withArgs(user.address, 1);
    });

    it("reverts if caller lacks BET_MANAGER_ROLE", async function () {
      await expect(registry.connect(other).recordLoss(user.address)).to.be.reverted;
    });

    it("reverts if user is not registered", async function () {
      await expect(
        registry.connect(betRegistry).recordLoss(other.address)
      ).to.be.revertedWith("User not registered");
    });
  });

  describe("getProfile()", function () {
    it("reverts for unregistered address", async function () {
      await expect(registry.getProfile(other.address)).to.be.revertedWith(
        "User not registered"
      );
    });
  });

  describe("isRegistered()", function () {
    it("returns false for unregistered address", async function () {
      expect(await registry.isRegistered(other.address)).to.be.false;
    });

    it("returns true after registration", async function () {
      await registry.connect(user).register(username);
      expect(await registry.isRegistered(user.address)).to.be.true;
    });
  });
});
