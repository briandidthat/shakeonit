const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getDataCenterFixture,
  getBetManagementFixture,
} = require("./utils");

describe("DataCenter", function () {
  let dataCenter, userManagement, betManagement;
  let multiSig, newMultiSig, addr1, addr2;

  beforeEach(async function () {
    [multiSig, newMultiSig, addr1, addr2] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSig.address);
    betManagement = await getBetManagementFixture(multiSig.address);
    // Deploy the DataCenter contract
    dataCenter = await getDataCenterFixture(
      multiSig.address,
      await userManagement.getAddress(),
      await betManagement.getAddress()
    );
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
    address = await dataCenter.getUserManagement();

    expect(address).to.be.a.properAddress;
    expect(address).to.equal(await userManagement.getAddress());
  });

  it("Should get the BetManagement contract address", async function () {
    expect(await dataCenter.getBetManagement()).to.be.a.properAddress;
  });

  it("Should check if an address is a user", async function () {
    // get the user management address
    await userManagement.connect(addr1).register();
    // check if the address is a user
    const isUser = await dataCenter.isUser(addr1.address);
    expect(isUser).to.be.true;
  });

  it("Should check if an address is not a user", async function () {
    // check if the address is a user
    const isUser = await dataCenter.isUser(addr1.address);
    expect(isUser).to.be.false;
  });

  it("Should set a new UserManagement contract address", async function () {
    // Deploy a new UserManagement contract
    let temp = await getUserManagementFixture(multiSig.address);
    let tempAddr = await temp.getAddress();
    // Set the new UserManagement contract address
    await dataCenter.connect(multiSig).setNewUserManagement(tempAddr);
    // Check if the new UserManagement contract address is set to the new UserManagement contract address
    expect(await dataCenter.getUserManagement()).to.equal(tempAddr);
  });

  it("Should set a new BetManagement contract address", async function () {
    // Deploy a new BetManagement contract
    let temp = await getBetManagementFixture(multiSig.address);
    let tempAddr = await temp.getAddress();
    // Set the new BetManagement contract address
    await dataCenter.connect(multiSig).setNewBetManagement(tempAddr);
    // Check if the new BetManagement contract address is set to the new BetManagement contract address
    expect(await dataCenter.getBetManagement()).to.equal(tempAddr);
  });

  it("Should revert when unauthorized account tries to update the usermanagement addr", async function () {
    // Set the new UserManagement contract address
    await expect(
      dataCenter.connect(addr1).setNewUserManagement(addr2.address)
    ).to.be.revertedWithCustomError(
      dataCenter,
      "AccessControlUnauthorizedAccount"
    );
  });
});
