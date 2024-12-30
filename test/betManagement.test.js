const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
} = require("./utils");

describe("BetManagement", function () {
  let betManagement, userManagement;
  let multiSigWallet, initiator, acceptor, arbiter;

  beforeEach(async function () {
    [multiSigWallet, initiator, acceptor, arbiter] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSigWallet.address);
    betManagement = await getBetManagementFixture(multiSigWallet.address);

    // register users
    await userManagement.connect(initiator).register();
    await userManagement.connect(acceptor).register();
    await userManagement.connect(arbiter).register();
  });

  it("Should deploy the BetManagement contract", async function () {
    expect(await betManagement.getAddress()).to.be.a.properAddress;
  });
});
