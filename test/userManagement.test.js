const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
} = require("./utils");

describe("UserManagement", function () {
  let userManagement, betManagement;
  let multiSigWallet, user, betManagementAddress;
  beforeEach(async function () {
    [multiSigWallet, user] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSigWallet.address);
    betManagement = await getBetManagementFixture(multiSigWallet.address);
    betManagementAddress = await betManagement.getAddress();
    // register user for testing
    await userManagement.connect(user).register("tester", betManagementAddress);
  });

  it("Should deploy the UserManagement contract", async function () {
    expect(await userManagement.getAddress()).to.be.a.properAddress;
  });

  it("Should revert when trying to register an already registered user", async function () {
    await expect(
      userManagement.connect(user).register("tester",betManagementAddress)
    ).to.be.revertedWith("User already registered");
  });

  it("Should return the user storage address", async function () {
    expect(await userManagement.getUserStorage(user.address)).to.be.a
      .properAddress;
  });

  it("Should return the user count", async function () {
    expect(await userManagement.getUserCount()).to.equal(1);
  });

  it("Should return the user list", async function () {
    expect(await userManagement.getUsers()).to.contain(user.address);
  });
});
