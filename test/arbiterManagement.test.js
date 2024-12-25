const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  abi,
} = require("../artifacts/contracts/ArbiterManagement.sol/ArbiterManagement.json");

describe("ArbiterManagement", function () {
  let arbiterManagement;
  let multiSig, dataCenter, addr1, addr2;

  beforeEach(async function () {
    [multiSig, dataCenter, addr1, addr2] = await ethers.getSigners();
    // Deploy the ArbiterManagement contract
    arbiterManagement = await ethers.deployContract("ArbiterManagement", [
      multiSig.address,
      dataCenter.address,
    ]);
  });

  it("Should deploy the ArbiterManagement contract", async function () {
    expect(await arbiterManagement.getAddress()).to.properAddress;
  });

  it("Should add an arbiter", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    expect(await arbiterManagement.isRegistered(addr1.address)).to.be.true;
  });

  it("Should revert when adding a zero address as arbiter", async function () {
    await expect(
      arbiterManagement.connect(dataCenter).addArbiter(ethers.ZeroAddress)
    ).to.be.revertedWith("Zero address not allowed");
  });

  it("Should revert when adding an already registered arbiter", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    await expect(
      arbiterManagement.connect(dataCenter).addArbiter(addr1.address)
    ).to.be.revertedWith("Arbiter already added");
  });

  it("Should get the list of arbiters", async function () {
    // Add arbiters
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    await arbiterManagement.connect(dataCenter).addArbiter(addr2.address);
    // Get the list of arbiters
    const arbiters = await arbiterManagement.getArbiters();

    expect(arbiters).to.include(addr1.address);
    expect(arbiters).to.include(addr2.address);
  });

  it("Should get the list of blocked arbiters", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    await arbiterManagement
      .connect(multiSig)
      .blockArbiter(addr1.address, "Violation");
    const blockedArbiters = await arbiterManagement.getBlockedArbiters();
    expect(blockedArbiters).to.include(addr1.address);
  });

  it("Should get the arbiter contract address", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    const arbiterAddress = await arbiterManagement.getArbiter(addr1.address);
    expect(arbiterAddress).to.properAddress;
  });

  it("Should get the multi-sig wallet address", async function () {
    expect(await arbiterManagement.getMultiSig()).to.equal(multiSig.address);
  });

  it("Should check if an address is registered as an arbiter", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    const isRegistered = await arbiterManagement.isRegistered(addr1.address);
    expect(isRegistered).to.be.true;
  });

  it("Should suspend an arbiter", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    await arbiterManagement
      .connect(multiSig)
      .suspendArbiter(addr1.address, "Misconduct");
    // get the arbiter status
    const arbiterStatus = await arbiterManagement.getArbiterStatus(
      addr1.address
    );
    expect(arbiterStatus).to.equal(2); // 2 is the status for SUSPENDED
  });

  it("Should block an arbiter", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    await arbiterManagement
      .connect(multiSig)
      .blockArbiter(addr1.address, "Repeated Misconduct");
    // get the arbiter status
    const arbiterStatus = await arbiterManagement.getArbiterStatus(
      addr1.address
    );
    expect(arbiterStatus).to.equal(3); // 3 is the status for BLOCKED
  });

  it("Should penalize an arbiter", async function () {
    await arbiterManagement.connect(dataCenter).addArbiter(addr1.address);
    const arbiterContract = await arbiterManagement.getArbiter(addr1.address);
    const Arbiter = await ethers.getContractFactory("Arbiter");
    const arbiter = Arbiter.attach(arbiterContract);
    const token = await ethers.getContractFactory("MockERC20");
    const mockToken = await token.deploy(
      "Mock Token",
      "MTK",
      18,
      ethers.parseEther("1000")
    );
    await mockToken.deployed();
    await arbiterManagement
      .connect(multiSig)
      .penalizeArbiter(
        addr1.address,
        mockToken.address,
        ethers.parseEther("10")
      );
    // Assuming the penalize function in Arbiter contract transfers tokens to a specific address
    expect(await mockToken.balanceOf(arbiterContract)).to.equal(
      ethers.utils.parseEther("10")
    );
  });
});
