const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
} = require("../utils");

describe("UserManagement", function () {
  let userManagement, betManagement;
  let multiSigWallet, user, betManagementAddress, userStorageAddress;
  beforeEach(async function () {
    [multiSigWallet, user] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSigWallet);
    betManagement = await getBetManagementFixture(multiSigWallet);
    betManagementAddress = await betManagement.getAddress();
    // register user for testing
    await userManagement
      .connect(user)
      .register(ethers.encodeBytes32String("tester"), betManagementAddress);
    const userDetails = await userManagement.getUser(user.address);
    userStorageAddress = userDetails.userContract;
  });

  it("Should deploy the UserManagement contract", async function () {
    expect(await userManagement.getAddress()).to.be.a.properAddress;
  });

  it("Should return the user Details object", async function () {
    const userDetails = await userManagement.getUser(user.address);

    expect(userDetails.username).to.be.equal(
      ethers.encodeBytes32String("tester")
    );
    expect(userDetails.userContract).to.be.equal(userStorageAddress);
    expect(userDetails.signer).to.be.equal(user.address);
  });

  it("Should revert when trying to register an already registered user", async function () {
    await expect(
      userManagement
        .connect(user)
        .register(ethers.encodeBytes32String("tester"), betManagementAddress)
    ).to.be.revertedWith("User already registered");
  });

  it("Should return the user storage address", async function () {
    const userDetails = await userManagement.getUser(user.address);
    expect(userDetails.userContract).to.be.a.properAddress;
    expect(userDetails.signer).to.equal(user.address);
    expect(userDetails.username).to.equal(ethers.encodeBytes32String("tester"));
  });

  it("Should return the user count", async function () {
    expect(await userManagement.getUserCount()).to.equal(1);
  });

  it("Should return the user list", async function () {
    expect(await userManagement.getUsers()).to.contain(user.address);
  });
});
