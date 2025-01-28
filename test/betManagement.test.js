const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getTokenFixture,
} = require("../utils");

const {
  abi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");

describe("BetManagement", function () {
  let initiatorDetails, arbiterDetails;
  let betManagement, userManagement, initiatorContract, token;
  let multiSig,
    initiator,
    acceptor,
    arbiter,
    tokenAddress,
    betManagementAddress;

  beforeEach(async function () {
    [multiSig, initiator, acceptor, arbiter] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSig);
    betManagement = await getBetManagementFixture(multiSig);
    betManagementAddress = await betManagement.getAddress();

    // deploy TestToken
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();

    // register user
    await userManagement
      .connect(initiator)
      .register("initiator", betManagementAddress);
    await userManagement
      .connect(arbiter)
      .register("arbiter", betManagementAddress);

    // get user storage addresses
    let initiatorContractAddress = await userManagement.getUserStorage(
      initiator.address
    );
    // create user details object
    initiatorDetails = {
      owner: initiator.address,
      storageAddress: initiatorContractAddress,
    };

    const arbiterContractAddress = await userManagement.getUserStorage(
      arbiter.address
    );

    arbiterDetails = {
      owner: arbiter.address,
      storageAddress: arbiterContractAddress,
    };

    // create pointer to user storage contract
    initiatorContract = await ethers.getContractAt(
      abi,
      initiatorContractAddress
    );

    // send 1000 tokens to initiator
    await token
      .connect(multiSig)
      .transfer(initiator.address, ethers.parseEther("1000"));

    // approve the user storage contract to transfer tokens for deposit
    await token
      .connect(initiator)
      .approve(initiatorDetails.storageAddress, ethers.MaxUint256);

    // deposit 1000 test tokens in storage contract
    await initiatorContract
      .connect(initiator)
      .deposit(tokenAddress, ethers.parseEther("1000"));
  });

  it("Should deploy the BetManagement contract", async function () {
    expect(await betManagement.getAddress()).to.be.a.properAddress;
  });

  it("Should create a bet", async function () {
    // grant approval rights to the betManagement contract
    await initiatorContract
      .connect(initiator)
      .grantApproval(
        tokenAddress,
        betManagementAddress,
        ethers.parseEther("1000")
      );

    // approve the bet management contract to create bets
    await initiatorContract
      .connect(initiator)
      .grantApproval(tokenAddress, betManagementAddress, ethers.MaxUint256);

    // deploy the bet
    await betManagement
      .connect(initiator)
      .deployBet(
        tokenAddress,
        initiatorDetails,
        arbiterDetails,
        ethers.parseEther("1000"),
        ethers.parseEther("50"),
        ethers.parseEther("50"),
        ethers.parseEther("1900"),
        "Condition"
      );
    // get the bet count
    let betCount = await betManagement.getBetCount();

    expect(betCount).to.equal(1);
  });

  it("Should revert when calling deployBet if initiator has not granted approval rights", async function () {
    await expect(
      betManagement
        .connect(initiator)
        .deployBet(
          tokenAddress,
          initiatorDetails,
          arbiterDetails,
          ethers.parseEther("1000"),
          ethers.parseEther("50"),
          ethers.parseEther("50"),
          ethers.parseEther("1900"),
          "Condition"
        )
    ).to.be.revertedWith("Insufficient allowance");
  });

  it("Should revert when calling acceptBet if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(initiator).acceptBet()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });

  it("Should revert when calling reportCancellation if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(initiator).reportCancellation()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });

  it("Should revert when calling reportSettlement if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(initiator).reportBetSettled()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });

  it("Should revert when calling declareWinner if caller is not a bet contract", async function () {
    await expect(
      betManagement.connect(initiator).reportWinnerDeclared()
    ).to.be.revertedWith("Restricted: caller is missing the required role");
  });
});
