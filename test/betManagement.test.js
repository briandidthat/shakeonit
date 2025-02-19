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

  describe("Authorization", function () {
    const mockBetDetails = {
      betContract: "0x8dAF17A20c9DBA35f005b6324F493785D239719d",
      token: "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0",
      initiator: [
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        "0x6F1216D1BFe15c98520CA1434FC1d9D57AC95321",
      ],
      arbiter: [
        "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
        "0xCBd5431cC04031d089c90E7c83288183A6Fe545d",
      ],
      acceptor: [
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
      ],
      winner: "0x0000000000000000000000000000000000000000",
      loser: "0x0000000000000000000000000000000000000000",
      stake: 1000000000000000000000n,
      arbiterFee: 50000000000000000000n,
      platformFee: 50000000000000000000n,
      payout: 1900000000000000000000n,
      status: 1n,
    };
    it("Should revert when calling acceptBet if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(initiator).acceptBet(mockBetDetails)
      ).to.be.revertedWith("Restricted: caller is missing the required role");
    });

    it("Should revert when calling reportCancellation if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(initiator).reportCancellation(mockBetDetails)
      ).to.be.revertedWith("Restricted: caller is missing the required role");
    });

    it("Should revert when calling reportSettlement if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(initiator).reportBetSettled(mockBetDetails)
      ).to.be.revertedWith("Restricted: caller is missing the required role");
    });

    it("Should revert when calling declareWinner if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(initiator).reportWinnerDeclared(mockBetDetails)
      ).to.be.revertedWith("Restricted: caller is missing the required role");
    });
  });
});
