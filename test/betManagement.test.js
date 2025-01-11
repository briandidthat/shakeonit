const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getTokenFixture,
} = require("./utils");

const {
  abi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");

describe("BetManagement", function () {
  let initiatorDetails, acceptorDetails, arbiterDetails;
  let betManagement, userManagement, token;
  let multiSig,
    initiator,
    acceptor,
    arbiter,
    tokenAddress,
    betManagementAddress;

  beforeEach(async function () {
    [multiSig, addr1, addr2, addr3] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSig.address);
    betManagement = await getBetManagementFixture(multiSig.address);
    betManagementAddress = await betManagement.getAddress();

    // register users
    await userManagement
      .connect(addr1)
      .register("initiator", betManagementAddress);
    await userManagement
      .connect(addr2)
      .register("acceptor", betManagementAddress);
    await userManagement
      .connect(addr3)
      .register("arbiter", betManagementAddress);

    // get user storage addresses
    initiator = await userManagement.getUserStorage(addr1.address);
    acceptor = await userManagement.getUserStorage(addr2.address);
    arbiter = await userManagement.getUserStorage(addr3.address);

    initiatorDetails = {
      owner: addr1.address,
      storageAddress: initiator,
    };
    acceptorDetails = {
      owner: addr2.address,
      storageAddress: acceptor,
    };
    arbiterDetails = {
      owner: addr3.address,
      storageAddress: arbiter,
    };

    // deploy TestToken
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();
    // send 10000 tokens to initiator
    await token.connect(multiSig).transfer(initiator, 10000);
  });

  it("Should deploy the BetManagement contract", async function () {
    expect(await betManagement.getAddress()).to.be.a.properAddress;
  });

  it("Should create a bet", async function () {
    // get the initiator's user storage contract (addr1)
    let userStorageContract = await ethers.getContractAt(abi, initiator);
    // grant approval rights to the betManagement contract
    await userStorageContract
      .connect(addr1)
      .grantApproval(tokenAddress, betManagementAddress, 1000);
    // deploy the bet
    await betManagement
      .connect(addr1)
      .deployBet(
        tokenAddress,
        initiatorDetails,
        arbiterDetails,
        1000,
        50,
        50,
        1900,
        "Condition"
      );
    // get the bet count
    let betCount = await betManagement.getBetCount();

    expect(betCount).to.equal(1);
  });

  it("Should revert when calling deployBet if initiator has not granted approval rights", async function () {
    await expect(
      betManagement
        .connect(addr1)
        .deployBet(
          tokenAddress,
          initiatorDetails,
          arbiterDetails,
          1000,
          50,
          50,
          1900,
          "Condition"
        )
    ).to.be.revertedWith("Insufficient allowance");
  });

  it("Should revert when calling acceptBet if caller is not a bet contract", async function () {
    await expect(betManagement.connect(addr1).acceptBet()).to.be.revertedWith(
      "Restricted: caller is missing the required role"
    );
  });

  it("Should revert when calling reportCancellation if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(addr1).reportCancellation()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });

  it("Should revert when calling reportSettlement if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(addr1).reportBetSettled()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });

  it("Should revert when calling declareWinner if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(addr1).reportWinnerDeclared()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });
});
