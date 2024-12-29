const { expect } = require("chai");
const { ethers } = require("hardhat");
const { getUserManagementFixture } = require("./utils");

describe("UserManagement", function () {
  let userManagement;
  let multiSigWallet, user;
  beforeEach(async function () {
    [multiSigWallet, user] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSigWallet.address);
    // register user for testing
    await userManagement.connect(user).register();
  });

  it("Should deploy the UserManagement contract", async function () {
    expect(await userManagement.getAddress()).to.be.a.properAddress;
  });

  it("Should revert when trying to register an already registered user", async function () {
    await expect(userManagement.connect(user).register()).to.be.revertedWith(
      "User already registered"
    );
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
