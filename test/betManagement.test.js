const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getTokenFixture,
  getEventObject,
} = require("../utils");

const {
  abi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");
const { abi: betAbi } = require("../artifacts/contracts/Bet.sol/Bet.json");

describe("BetManagement", function () {
  let creatorHash = ethers.encodeBytes32String("creator");
  let challengerHash = ethers.encodeBytes32String("challenger");
  let arbiterHash = ethers.encodeBytes32String("arbiter");

  let mockBetRequest;

  let creatorDetails, arbiterDetails, challengerDetails;
  let betManagement, userManagement, creatorContract, token;
  let multiSig,
    creator,
    challenger,
    arbiter,
    tokenAddress,
    betManagementAddress;

  beforeEach(async function () {
    [multiSig, creator, challenger, arbiter] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSig);
    betManagement = await getBetManagementFixture(multiSig);
    betManagementAddress = await betManagement.getAddress();

    // deploy TestToken
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();

    // register user
    await userManagement
      .connect(creator)
      .register(creatorHash, betManagementAddress);
    await userManagement
      .connect(arbiter)
      .register(arbiterHash, betManagementAddress);
    await userManagement
      .connect(challenger)
      .register(challengerHash, betManagementAddress);

    // get user storage addresses
    const creatorObject = await userManagement.getUser(creator.address);
    creatorDetails = creatorObject.toObject();
    const arbiterObject = await userManagement.getUser(arbiter.address);
    arbiterDetails = arbiterObject.toObject();
    const challengerObject = await userManagement.getUser(challenger.address);
    challengerDetails = challengerObject.toObject();

    // create pointer for user storage contract
    creatorContract = new ethers.Contract(
      creatorDetails.userContract,
      abi,
      creator
    );
    challengerContract = new ethers.Contract(
      challengerDetails.userContract,
      abi,
      challenger
    );

    // send 1000 tokens to creator
    await token
      .connect(multiSig)
      .transfer(creator.address, ethers.parseEther("1000"));
    await token
      .connect(multiSig)
      .transfer(challenger.address, ethers.parseEther("1000"));

    // approve the user storage contract to transfer tokens for deposit
    await token
      .connect(creator)
      .approve(creatorDetails.userContract, ethers.MaxUint256);
    await token
      .connect(challenger)
      .approve(challengerDetails.userContract, ethers.MaxUint256);

    // deposit 1000 test tokens in storage contract
    await creatorContract
      .connect(creator)
      .deposit(tokenAddress, ethers.parseEther("1000"));
    await challengerContract
      .connect(challenger)
      .deposit(tokenAddress, ethers.parseEther("1000"));

    mockBetRequest = {
      betType: 1,
      token: tokenAddress,
      creator: creatorDetails,
      challenger: challengerDetails,
      arbiter: arbiterDetails,
      stake: ethers.parseEther("1000"),
      arbiterFee: ethers.parseEther("50"),
      platformFee: ethers.parseEther("50"),
      payout: ethers.parseEther("1900"),
      condition: "Condition",
    };
  });

  it("Should deploy the BetManagement contract", async function () {
    expect(await betManagement.getAddress()).to.be.a.properAddress;
  });

  it("Should create a bet", async function () {
    // deploy the bet
    await betManagement.connect(creator).deployBet(mockBetRequest);
    // get the bet count
    let betCount = await betManagement.getBetCount();

    expect(betCount).to.equal(1);
  });

  describe("Events", function () {
    it("Should create a bet and emit BetCreated event", async function () {
      // deploy the bet
      const tx = await betManagement.connect(creator).deployBet(mockBetRequest);

      // get the bet count
      let betCount = await betManagement.getBetCount();
      expect(betCount).to.equal(1);

      // check the event
      const receipt = await tx.wait();
      const event = getEventObject("BetCreated", receipt.logs);
      expect(event.args.betAddress).to.be.a.properAddress;
      expect(event.args.creator).to.equal(creatorDetails.userContract);
      expect(event.args.arbiter).to.equal(arbiterDetails.userContract);
      expect(event.args.token).to.equal(tokenAddress);
      expect(event.args.stake).to.equal(ethers.parseEther("1000"));
      expect(event.args.payout).to.equal(ethers.parseEther("1900"));
    });
  });

  describe("Authorization", function () {
    const mockBetDetails = {
      betType: 0n,
      betContract: "0x8dAF17A20c9DBA35f005b6324F493785D239719d",
      token: "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0",
      creator: "0x6F1216D1BFe15c98520CA1434FC1d9D57AC95321",
      arbiter: "0xCBd5431cC04031d089c90E7c83288183A6Fe545d",
      challenger: "0x0000000000000000000000000000000000000000",
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
        betManagement.connect(creator).acceptBet(mockBetDetails)
      ).to.be.revertedWith("Not a valid bet contract");
    });

    it("Should revert when calling reportCancellation if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(creator).reportCancellation(mockBetDetails)
      ).to.be.revertedWith("Not a valid bet contract");
    });

    it("Should revert when calling reportSettlement if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(creator).reportBetSettled(mockBetDetails)
      ).to.be.revertedWith("Not a valid bet contract");
    });

    it("Should revert when calling declareWinner if caller is not a bet contract", async function () {
      await expect(
        betManagement.connect(creator).reportWinnerDeclared(mockBetDetails)
      ).to.be.revertedWith("Not a valid bet contract");
    });
  });
});
