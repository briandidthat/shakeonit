const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getTokenFixture,
  getBetManagementFixture,
} = require("../utils");
const {
  abi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");

describe("UserStorage", function () {
  let userManagement, userStorage, token, betManagement;
  let multiSig,
    initiator,
    addr2,
    tokenAddress,
    userStorageAddress,
    betManagementAddress;

  beforeEach(async function () {
    [multiSig, initiator, addr2] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSig);
    betManagement = await getBetManagementFixture(multiSig);
    betManagementAddress = await betManagement.getAddress();
    // Register initiator
    await userManagement
      .connect(initiator)
      .register("tester", betManagementAddress);
    // get user strorage address
    userStorageAddress = await userManagement.getUserStorage(initiator.address);
    userStorage = await ethers.getContractAt(abi, userStorageAddress);

    // deploy TestToken
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();
    // send 10000 tokens to initiator
    await token.connect(multiSig).transfer(initiator.address, 10000);
    // approve user storage to spend 1000 tokens
    await token.connect(initiator).approve(userStorage, 1000);
  });

  it("Should have deployed UserStorage", async function () {
    expect(userStorageAddress).to.be.a.properAddress;
  });

  it("Should have correct owner", async function () {
    expect(await userStorage.getOwner()).to.equal(initiator.address);
  });

  it("Should deposit to the contract", async function () {
    // deposit 1000 tokens to user storage
    await userStorage.connect(initiator).deposit(tokenAddress, 1000);
    // check balance
    expect(await userStorage.getTokenBalance(tokenAddress)).to.equal(1000);
  });

  it("Should withdraw from the contract", async function () {
    // deposit 1000 tokens to user storage
    await userStorage.connect(initiator).deposit(tokenAddress, 1000);
    // withdraw 500 tokens
    await userStorage.connect(initiator).withdraw(tokenAddress, 500);
    // check balance
    expect(await userStorage.getTokenBalance(tokenAddress)).to.equal(500);
  });

  describe("Approvals", function () {
    it("Should have granted approval to bet management address on deposit", async function () {
      // deposit 1000 tokens to user storage
      await userStorage.connect(initiator).deposit(tokenAddress, 1000);
      // check approval
      expect(
        await token.allowance(userStorageAddress, betManagementAddress)
      ).to.equal(ethers.MaxUint256);
    });

    it("Should grant approval to bet management address", async function () {
      // revoke approval
      await userStorage.connect(initiator).revokeApproval(tokenAddress);
      // grant approval to bet management
      await userStorage.connect(initiator).grantApproval(tokenAddress, 1000);
      // check approval
      expect(
        await token.allowance(userStorageAddress, betManagementAddress)
      ).to.equal(1000);
    });

    it("Should revoke approval to bet management address", async function () {
      // revoke approval
      await userStorage.connect(initiator).revokeApproval(tokenAddress);
      // check approval
      expect(
        await token.allowance(userStorageAddress, betManagementAddress)
      ).to.equal(0);
    });
  });

  describe("Authorization", function () {
    it("Should revert if unauthorized user tries to deposit", async function () {
      // deposit 1000 tokens to user storage
      await expect(
        userStorage.connect(multiSig).deposit(tokenAddress, 1000)
      ).to.be.revertedWith("Restricted to owner");
    });

    it("Should revert if unauthorized user tries to withdraw", async function () {
      // deposit 1000 tokens to user storage
      await userStorage.connect(initiator).deposit(tokenAddress, 1000);
      // withdraw 500 tokens
      await expect(
        userStorage.connect(multiSig).withdraw(tokenAddress, 500)
      ).to.be.revertedWith("Restricted to owner");
    });
  });
});
