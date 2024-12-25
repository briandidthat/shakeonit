const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DataCenter", function () {
  let dataCenter;
  let multiSig, newMultiSig, addr1, addr2;

  beforeEach(async function () {
    [multiSig, newMultiSig, addr1, addr2] = await ethers.getSigners();
    // Deploy the DataCenter contract
    dataCenter = await ethers.deployContract("DataCenter", [
      multiSig.address,
      addr1.address,
    ]);
  });

  it("Should set a new multi-sig wallet", async function () {
    await dataCenter.connect(multiSig).setNewMultiSig(newMultiSig.address);
    // Check if the new multi-sig wallet is set to the new multi-sig wallet address
    expect(await dataCenter.getMultiSig()).to.equal(newMultiSig.address);
  });

  it("Should revert when setting a zero address as multi-sig wallet", async function () {
    await expect(
      dataCenter.setNewMultiSig(ethers.ZeroAddress)
    ).to.be.revertedWith("Zero address not allowed");
  });

  it("Should get the UserManagement contract address", async function () {
    expect(await dataCenter.getUserManagement()).to.be.a.properAddress;
  });

  it("Should get the ArbiterManagement contract address", async function () {
    expect(await dataCenter.getArbiterManagement()).to.be.a.properAddress;
  });

  it("Should get the BetManagement contract address", async function () {
    expect(await dataCenter.getBetManagement()).to.be.a.properAddress;
  });

  it("Should get the bet factory address", async function () {
    expect(await dataCenter.getBetFactory()).to.be.a.properAddress;
  });

  //   it("Should get the user storage address", async function () {
  //     await userManagement.addUser(addr1.address);
  //     const userStorageAddress = await dataCenter.getUserStorage(addr1.address);
  //     expect(userStorageAddress).to.properAddress;
  //   });

  //   it("Should get the arbiter address", async function () {
  //     await arbiterManagement.addArbiter(addr1.address);
  //     const arbiterAddress = await dataCenter.getArbiter(addr1.address);
  //     expect(arbiterAddress).to.equal(addr1.address);
  //   });

  //   it("Should check if an address is an arbiter", async function () {
  //     await arbiterManagement.addArbiter(addr1.address);
  //     const isArbiter = await dataCenter.isArbiter(addr1.address);
  //     expect(isArbiter).to.be.true;
  //   });

  // it("Should check if an address is a user", async function () {
  //   await userManagement.addUser(addr1.address);
  //   const isUser = await dataCenter.isUser(addr1.address);
  //   expect(isUser).to.be.true;
  // });
});
