const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DataCenter", function () {
  let DataCenter,
    dataCenter,
    UserStorage,
    userStorage,
    owner,
    addr1,
    addr2,
    addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy the DataCenter contract
    DataCenter = await ethers.getContractFactory("DataCenter");
    dataCenter = await DataCenter.deploy(owner.address);
    await dataCenter.deployed();
  });

  it("Should deploy the DataCenter contract", async function () {
    expect(dataCenter.address).to.properAddress;
  });

  it("Should add a new user", async function () {
    const tx = await dataCenter.addUser(addr1.address);
    await tx.wait();

    const userStorageAddress = await dataCenter.userStorageRegistry(
      addr1.address
    );
    expect(userStorageAddress).to.properAddress;
  });

  it("Should block an arbiter", async function () {
    const tx = await dataCenter.blockArbiter(addr1.address, "Misconduct");
    await tx.wait();

    const isBlocked = await dataCenter.isArbiterBlocked(addr1.address);
    expect(isBlocked).to.be.true;
  });

  it("Should revert when blocking a zero address arbiter", async function () {
    await expect(
      dataCenter.blockArbiter(ethers.constants.AddressZero, "Invalid address")
    ).to.be.revertedWith("Zero address not allowed");
  });

  it("Should add an arbiter", async function () {
    const tx = await dataCenter.addArbiter(addr1.address);
    await tx.wait();

    const isArbiter = await dataCenter.isArbiter(addr1.address);
    expect(isArbiter).to.be.true;
  });

  it("Should revert when adding a zero address arbiter", async function () {
    await expect(
      dataCenter.addArbiter(ethers.constants.AddressZero)
    ).to.be.revertedWith("Zero address not allowed");
  });

  it("Should create a new bet", async function () {
    await dataCenter.addUser(addr1.address);
    const userStorageAddress = await dataCenter.userStorageRegistry(
      addr1.address
    );

    const tx = await dataCenter.createBet(
      addr2.address,
      addr1.address,
      addr3.address,
      ethers.constants.AddressZero,
      ethers.utils.parseEther("10"),
      Math.floor(Date.now() / 1000) + 3600,
      "Test Bet"
    );
    await tx.wait();

    const betDetails = await dataCenter.getBetDetails(
      addr2.address,
      addr1.address
    );
    expect(betDetails.initiator).to.equal(addr1.address);
  });

  it("Should update a bet", async function () {
    await dataCenter.addUser(addr1.address);
    await dataCenter.addUser(addr2.address);

    const betDetails = {
      betContract: addr3.address,
      initiator: addr1.address,
      acceptor: addr2.address,
      fundToken: ethers.constants.AddressZero,
      amount: ethers.utils.parseEther("10"),
      deadline: Math.floor(Date.now() / 1000) + 3600,
      message: "Test Bet",
    };

    await dataCenter.createBet(
      betDetails.betContract,
      betDetails.initiator,
      betDetails.acceptor,
      betDetails.fundToken,
      betDetails.amount,
      betDetails.deadline,
      betDetails.message
    );

    const updatedBetDetails = {
      ...betDetails,
      amount: ethers.utils.parseEther("20"),
    };

    await dataCenter.updateBet(updatedBetDetails);

    const storedBetDetails = await dataCenter.getBetDetails(
      betDetails.betContract,
      betDetails.initiator
    );
    expect(storedBetDetails.amount).to.equal(updatedBetDetails.amount);
  });

  it("Should accept a bet", async function () {
    await dataCenter.addUser(addr1.address);
    await dataCenter.addUser(addr2.address);

    const betDetails = {
      betContract: addr3.address,
      initiator: addr1.address,
      acceptor: addr2.address,
      fundToken: ethers.constants.AddressZero,
      amount: ethers.utils.parseEther("10"),
      deadline: Math.floor(Date.now() / 1000) + 3600,
      message: "Test Bet",
    };

    await dataCenter.createBet(
      betDetails.betContract,
      betDetails.initiator,
      betDetails.acceptor,
      betDetails.fundToken,
      betDetails.amount,
      betDetails.deadline,
      betDetails.message
    );

    await dataCenter.betAccepted(betDetails);

    const storedBetDetails = await dataCenter.getBetDetails(
      betDetails.betContract,
      betDetails.initiator
    );
    expect(storedBetDetails.acceptor).to.equal(betDetails.acceptor);
  });

  it("Should cancel a bet", async function () {
    await dataCenter.addUser(addr1.address);

    const betDetails = {
      betContract: addr3.address,
      initiator: addr1.address,
      acceptor: addr2.address,
      fundToken: ethers.constants.AddressZero,
      amount: ethers.utils.parseEther("10"),
      deadline: Math.floor(Date.now() / 1000) + 3600,
      message: "Test Bet",
    };

    await dataCenter.createBet(
      betDetails.betContract,
      betDetails.initiator,
      betDetails.acceptor,
      betDetails.fundToken,
      betDetails.amount,
      betDetails.deadline,
      betDetails.message
    );

    await dataCenter.cancelBet(betDetails.betContract, betDetails.initiator);

    const storedBetDetails = await dataCenter.getBetDetails(
      betDetails.betContract,
      betDetails.initiator
    );
    expect(storedBetDetails.status).to.equal("Cancelled");
  });

  it("Should set a new factory address", async function () {
    const newFactory = addr1.address;
    await dataCenter.setNewFactory(newFactory);

    const owner = await dataCenter.owner();
    expect(owner).to.equal(newFactory);
  });

  it("Should set and get platform percentage", async function () {
    const platformPercentage = 500; // 5%
    await dataCenter.setPlatformPercentage(platformPercentage);

    const storedPlatformPercentage = await dataCenter.getPlatformPercentage();
    expect(storedPlatformPercentage).to.equal(platformPercentage);
  });

  it("Should get user storage address", async function () {
    await dataCenter.addUser(addr1.address);
    const userStorageAddress = await dataCenter.getUserStorage(addr1.address);
    expect(userStorageAddress).to.properAddress;
  });

  it("Should get arbiter contract address", async function () {
    await dataCenter.addArbiter(addr1.address);
    const arbiterAddress = await dataCenter.getArbiter(addr1.address);
    expect(arbiterAddress).to.equal(addr1.address);
  });

  it("Should get the list of all users", async function () {
    await dataCenter.addUser(addr1.address);
    await dataCenter.addUser(addr2.address);

    const users = await dataCenter.getUsers();
    expect(users).to.include(addr1.address);
    expect(users).to.include(addr2.address);
  });

  it("Should get the list of all arbiters", async function () {
    await dataCenter.addArbiter(addr1.address);
    await dataCenter.addArbiter(addr2.address);

    const arbiters = await dataCenter.getArbiters();
    expect(arbiters).to.include(addr1.address);
    expect(arbiters).to.include(addr2.address);
  });

  it("Should get the list of all blocked arbiters", async function () {
    await dataCenter.blockArbiter(addr1.address, "Misconduct");
    await dataCenter.blockArbiter(addr2.address, "Misconduct");

    const blockedArbiters = await dataCenter.getBlockedArbiters();
    expect(blockedArbiters).to.include(addr1.address);
    expect(blockedArbiters).to.include(addr2.address);
  });

  it("Should get the list of all bets", async function () {
    await dataCenter.addUser(addr1.address);

    const betDetails = {
      betContract: addr3.address,
      initiator: addr1.address,
      acceptor: addr2.address,
      fundToken: ethers.constants.AddressZero,
      amount: ethers.utils.parseEther("10"),
      deadline: Math.floor(Date.now() / 1000) + 3600,
      message: "Test Bet",
    };

    await dataCenter.createBet(
      betDetails.betContract,
      betDetails.initiator,
      betDetails.acceptor,
      betDetails.fundToken,
      betDetails.amount,
      betDetails.deadline,
      betDetails.message
    );

    const bets = await dataCenter.getBets();
    expect(bets).to.include(betDetails.betContract);
  });
});
