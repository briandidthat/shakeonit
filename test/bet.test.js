const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getTokenFixture,
  getEventObject,
} = require("../utils");
const {
  abi: userStorageAbi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");
const { abi: betAbi } = require("../artifacts/contracts/Bet.sol/Bet.json");

const BET_TYPES = {
  OPEN: 0,
  PRIVATE: 1,
};

describe("Bet", function () {
  let creatorHash = ethers.encodeBytes32String("creator");
  let challengerHash = ethers.encodeBytes32String("challenger");
  let arbiterHash = ethers.encodeBytes32String("arbiter");
  let creatorObject, challengerObject, arbiterObject;
  let betManagement,
    userManagement,
    bet,
    token,
    challengerContract,
    creatorContract;
  let multiSig, betManagementAddress, tokenAddress, betAddress;
  beforeEach(async function () {
    [multiSig, creator, challenger, arbiter] = await ethers.getSigners();
    // deploy user management contract
    userManagement = await getUserManagementFixture(multiSig);
    // deploy bet management contract and get address
    betManagement = await getBetManagementFixture(multiSig);
    betManagementAddress = await betManagement.getAddress();
    // deploy test token contract and get address
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();

    // register users
    await userManagement
      .connect(creator)
      .register(creatorHash, betManagementAddress);
    await userManagement
      .connect(challenger)
      .register(challengerHash, betManagementAddress);
    await userManagement
      .connect(arbiter)
      .register(arbiterHash, betManagementAddress);
    // get user storage addresses
    const creatorResponse = await userManagement.getUser(creator.address);
    creatorObject = creatorResponse.toObject();
    const challengerResponse = await userManagement.getUser(challenger.address);
    challengerObject = challengerResponse.toObject();
    const arbiterResponse = await userManagement.getUser(arbiter.address);
    arbiterObject = arbiterResponse.toObject();

    // send 100000 tokens to creatorObject
    await token
      .connect(multiSig)
      .transfer(creator.address, ethers.parseEther("100000"));
    // send 100000 tokens to challengerObject
    await token
      .connect(multiSig)
      .transfer(challenger.address, ethers.parseEther("100000"));

    // get the creator's user storage contract (creator)
    creatorContract = await ethers.getContractAt(
      userStorageAbi,
      creatorObject.userContract
    );
    // get the challenger's user storage contract (challenger)
    challengerContract = await ethers.getContractAt(
      userStorageAbi,
      challengerObject.userContract
    );
    // get the arbiter's user storage contract (arbiter)
    arbiterContract = await ethers.getContractAt(
      userStorageAbi,
      arbiterObject.userContract
    );

    // simulate the user approving their storage contract for the first time for that token.
    // then, deposit 1000 tokens into user storage contract.
    await token
      .connect(creator)
      .approve(creatorObject.userContract, ethers.MaxUint256);
    await creatorContract
      .connect(creator)
      .deposit(tokenAddress, ethers.parseEther("10000"));

    // simulate the user approving their storage contract for the first time for that token.
    // then, deposit 1000 tokens into user storage contract.
    await token
      .connect(challenger)
      .approve(challengerObject.userContract, ethers.MaxUint256);
    await challengerContract
      .connect(challenger)
      .deposit(tokenAddress, ethers.parseEther("10000"));

    // deploy an open bet
    let tx = await betManagement.connect(creator).deployBet({
      betType: BET_TYPES.OPEN,
      token: tokenAddress,
      creator: creatorObject,
      arbiter: arbiterObject,
      challenger: {
        username: ethers.encodeBytes32String("challenger"),
        signer: ethers.ZeroAddress,
        userContract: ethers.ZeroAddress,
      },
      stake: ethers.parseEther("1000"),
      arbiterFee: ethers.parseEther("50"),
      platformFee: ethers.parseEther("50"),
      payout: ethers.parseEther("1900"),
      condition: "Condition",
    });
    let receipt = await tx.wait();
    const event = getEventObject("BetCreated", receipt.logs);
    // the first argument of the event is the bet address
    betAddress = event.args[0];
    // assign pointer to bet address
    bet = await ethers.getContractAt(betAbi, betAddress);
  });

  it("Should have deployed a bet", async function () {
    // assert
    expect(await betManagement.getBetCount()).to.be.equal(1);
  });

  describe("Private Bet Lifecycle", function () {
    let privateBet, privateBetAddress;

    beforeEach(async function () {
      // deploy an private bet
      let tx = await betManagement.connect(creator).deployBet({
        betType: BET_TYPES.PRIVATE,
        token: tokenAddress,
        creator: creatorObject,
        arbiter: arbiterObject,
        challenger: challengerObject,
        stake: ethers.parseEther("1000"),
        arbiterFee: ethers.parseEther("50"),
        platformFee: ethers.parseEther("50"),
        payout: ethers.parseEther("1900"),
        condition: "Condition",
      });

      let receipt = await tx.wait();
      const event = getEventObject("BetCreated", receipt.logs);
      // the first argument of the event is the bet address
      privateBetAddress = event.args[0];
      // assign pointer to bet address
      privateBet = await ethers.getContractAt(betAbi, privateBetAddress);
    });

    it("Should deploy a bet", async function () {
      // get bet details
      const betDetails = await privateBet.getBetDetails();
      // assert
      expect(betDetails.betContract).to.be.equal(privateBetAddress);
      expect(betDetails.token).to.be.equal(tokenAddress);
      expect(betDetails.creator).to.be.equal(creatorObject.userContract);
      expect(betDetails.arbiter).to.be.equal(arbiterObject.userContract);
      expect(betDetails.challenger).to.be.equal(
        challengerObject.userContract
      );
      expect(betDetails.stake).to.be.equal(ethers.parseEther("1000"));
      expect(betDetails.payout).to.be.equal(ethers.parseEther("1900"));
      expect(betDetails.platformFee).to.be.equal(ethers.parseEther("50"));
      expect(betDetails.arbiterFee).to.be.equal(ethers.parseEther("50"));
      expect(betDetails.status).to.be.equal(1);
      expect(betDetails.betType).to.be.equal(BET_TYPES.PRIVATE);
    });

    it("Should allow the challenger to accept the bet", async function () {
      // accept the bet
      await privateBet.connect(challenger).acceptBet(challengerObject);
      // assert
      expect(await token.balanceOf(privateBetAddress)).to.be.equal(
        ethers.parseEther("2000")
      );
      expect(await privateBet.getStatus()).to.be.equal(2);
      expect(await privateBet.getChallenger()).to.be.equal(
        challengerObject.userContract
      );
      expect(await challengerContract.getBets()).to.be.lengthOf(1);
    });
  });

  it("Should have the correct bet details", async function () {
    // assert
    expect(await bet.getCreator()).to.be.equal(creatorObject.userContract);
    expect(await bet.getArbiter()).to.be.equal(arbiterObject.userContract);
    expect(await bet.getStake()).to.be.equal(ethers.parseEther("1000"));
    expect(await bet.getPayout()).to.be.equal(ethers.parseEther("1900"));
    expect(await bet.getPlatformFee()).to.be.equal(ethers.parseEther("50"));
    expect(await bet.getArbiterFee()).to.be.equal(ethers.parseEther("50"));
    expect(await bet.getCondition()).to.be.equal("Condition");
    // assert the bet was added to the user storage contracts
    expect(await creatorContract.getBets()).to.be.lengthOf(1);
    expect(await arbiterContract.getBets()).to.be.lengthOf(1);
  });

  it("Should get the bet details", async function () {
    const betDetails = await bet.getBetDetails();
    // assert
    expect(betDetails.betContract).to.be.equal(betAddress);
    expect(betDetails.token).to.be.equal(tokenAddress);
    expect(betDetails.creator).to.be.equal(creatorObject.userContract);
    expect(betDetails.arbiter).to.be.equal(arbiterObject.userContract);
    // challenger is not set yet, same for winner and loser
    expect(betDetails.challenger).to.be.equal(ethers.ZeroAddress);
    expect(betDetails.winner).to.be.equal(ethers.ZeroAddress);
    expect(betDetails.loser).to.be.equal(ethers.ZeroAddress);
    expect(betDetails.status).to.be.equal(1);
    expect(betDetails.stake).to.be.equal(ethers.parseEther("1000"));
    expect(betDetails.payout).to.be.equal(ethers.parseEther("1900"));
    expect(betDetails.platformFee).to.be.equal(ethers.parseEther("50"));
    expect(betDetails.arbiterFee).to.be.equal(ethers.parseEther("50"));
  });

  it("Should allow the challenger to accept the bet", async function () {
    // accept the bet
    await bet.connect(challenger).acceptBet(challengerObject);
    // assert
    expect(await token.balanceOf(betAddress)).to.be.equal(
      ethers.parseEther("2000")
    );
    expect(await bet.getStatus()).to.be.equal(2);
    expect(await bet.getChallenger()).to.be.equal(
      challengerObject.userContract
    );
    expect(await challengerContract.getBets()).to.be.lengthOf(1);
  });

  it("Should allow the arbiter to declare the winner", async function () {
    // accept the bet
    await bet.connect(challenger).acceptBet(challengerObject);
    // declare the winner
    await bet.connect(arbiter).declareWinner(challengerObject);
    // assert
    expect(await bet.getStatus()).to.be.equal(3);
    expect(await bet.getWinner()).to.be.equal(challengerObject.userContract);
    expect(await bet.getLoser()).to.be.equal(creatorObject.userContract);
    expect(await token.balanceOf(betAddress)).to.be.equal(
      ethers.parseEther("1900")
    );
  });

  it("Should allow the winner to withdraw the winnings", async function () {
    // accept the bet
    await bet.connect(challenger).acceptBet(challengerObject);
    // declare the winner
    await bet.connect(arbiter).declareWinner(challengerObject);
    // withdraw the winnings
    await bet.connect(challenger).withdrawEarnings();
    // assert
    expect(await bet.getStatus()).to.be.equal(4);
    expect(await token.balanceOf(challengerObject.userContract)).to.be.equal(
      ethers.parseEther("10900")
    );
    expect(await token.balanceOf(arbiterObject.userContract)).to.be.equal(
      ethers.parseEther("50")
    );
    expect(await token.balanceOf(betAddress)).to.be.equal(0);
  });

  it("Should allow the creator to cancel the bet", async function () {
    // cancel the bet
    await bet.connect(creator).cancelBet();
    // assert
    expect(await bet.getStatus()).to.be.equal(5);
    expect(await token.balanceOf(betAddress)).to.be.equal(0);
    expect(await token.balanceOf(creatorObject.userContract)).to.be.equal(
      ethers.parseEther("10000")
    );
  });

  describe("View Functions", function () {
    it("Should return the correct bet status", async function () {
      // assert
      expect(await bet.getStatus()).to.be.equal(1);
    });

    it("Should return the correct bet participants", async function () {
      // assert
      expect(await bet.getCreator()).to.be.equal(creatorObject.userContract);
      expect(await bet.getChallenger()).to.be.equal(ethers.ZeroAddress);
      expect(await bet.getArbiter()).to.be.equal(arbiterObject.userContract);
    });

    it("should return a bets array of length 1 for all participants", async function () {
      const arbiterBets = await arbiterContract.getBets();
      const creatorBets = await creatorContract.getBets();

      expect(arbiterBets).to.be.lengthOf(1);
      expect(creatorBets).to.be.lengthOf(1);
    });
  });

  describe("Error Handling", function () {
    it("Should revert is user tries to update bet balance", async function () {
      await expect(
        bet
          .connect(creator)
          .updateBalance(tokenAddress, ethers.parseEther("10"))
      ).to.be.revertedWith("Restricted to bet mgmt");
    });
    it("Should revert if the creatorObject tries to declare the winner", async function () {
      // accept the bet
      await bet.connect(challenger).acceptBet(challengerObject);
      // declare the winner
      await expect(
        bet.connect(creator).declareWinner(creatorObject, challengerObject)
      ).to.be.revertedWith("Restricted to arbiter");
    });

    it("Should revert if loser tries to withdraw winnings", async function () {
      // accept the bet
      await bet.connect(challenger).acceptBet(challengerObject);
      // declare the winner
      await bet.connect(arbiter).declareWinner(challengerObject);
      // withdraw the winnings
      await expect(bet.connect(creator).withdrawEarnings()).to.be.revertedWith(
        "Restricted to winner"
      );
    });

    it("Should revert if the arbiter tries to withdraw earnings", async function () {
      // accept the bet
      await bet.connect(challenger).acceptBet(challengerObject);
      // declare the winner
      await bet.connect(arbiter).declareWinner(challengerObject);
      // withdraw the winnings
      await expect(bet.connect(arbiter).withdrawEarnings()).to.be.revertedWith(
        "Restricted to winner"
      );
    });

    it("Should revert if the multiSig tries to withdraw earnings", async function () {
      // accept the bet
      await bet.connect(challenger).acceptBet(challengerObject);
      // declare the winner
      await bet.connect(arbiter).declareWinner(challengerObject);
      // withdraw the winnings
      await expect(bet.connect(multiSig).withdrawEarnings()).to.be.revertedWith(
        "Restricted to winner"
      );
    });

    it("Should revert if the creator tries to accept the bet", async function () {
      // accept the bet
      await expect(
        bet.connect(creator).acceptBet(creatorObject)
      ).to.be.revertedWith("Invalid challenger");
    });

    it("Should revert if the arbiter tries to accept the bet", async function () {
      // accept the bet
      await expect(
        bet.connect(arbiter).acceptBet(arbiterObject)
      ).to.be.revertedWith("Invalid challenger");
    });

    it("Should revert if the challenger tries to accept the bet again", async function () {
      // accept the bet
      await bet.connect(challenger).acceptBet(challengerObject);
      // accept the bet again
      await expect(
        bet.connect(challenger).acceptBet(challengerObject)
      ).to.be.revertedWith("Bet must be in initiated status");
    });

    it("Should revert if the arbiter tries to cancel the bet", async function () {
      // cancel the bet
      await expect(bet.connect(arbiter).cancelBet()).to.be.revertedWith(
        "Restricted to creator"
      );
    });

    it("Should revert if the challenger tries to cancel the bet", async function () {
      // accept the bet
      await bet.connect(challenger).acceptBet(challengerObject);
      // cancel the bet
      await expect(bet.connect(challenger).cancelBet()).to.be.revertedWith(
        "Restricted to creator"
      );
    });

    it("Should revert if the multiSig tries to cancel the bet", async function () {
      // cancel the bet
      await expect(bet.connect(multiSig).cancelBet()).to.be.revertedWith(
        "Restricted to creator"
      );
    });

    it("Should revert if the arbiter tries to declare a winner without the bet being accepted", async function () {
      // declare the winner
      await expect(
        bet.connect(arbiter).declareWinner(challengerObject, creatorObject)
      ).to.be.revertedWith("Bet has not been funded yet");
    });
  });
});
