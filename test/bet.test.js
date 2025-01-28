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

describe("Bet", function () {
  let initiatorDetails, acceptorDetails, arbiterDetails;
  let betManagement,
    userManagement,
    bet,
    token,
    acceptorContract,
    initiatorContract;
  let multiSig,
    betManagementAddress,
    tokenAddress,
    initiator,
    acceptor,
    arbiter,
    betAddress;
  beforeEach(async function () {
    [multiSig, addr1, addr2, addr3] = await ethers.getSigners();
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
    // create user details objects
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

    // send 1000 tokens to initiator
    await token
      .connect(multiSig)
      .transfer(addr1.address, ethers.parseEther("1000"));
    // send 1000 tokens to acceptor
    await token
      .connect(multiSig)
      .transfer(addr2.address, ethers.parseEther("1000"));

    // get the initiator's user storage contract (addr1)
    initiatorContract = await ethers.getContractAt(userStorageAbi, initiator);
    // get the acceptor's user storage contract (addr2)
    acceptorContract = await ethers.getContractAt(userStorageAbi, acceptor);
    // get the arbiter's user storage contract (addr3)
    arbiterContract = await ethers.getContractAt(userStorageAbi, arbiter);

    // simulate the user approving their storage contract for the first time for that token.
    // then, deposit 1000 tokens into user storage contract.
    // then, approve the bet management contract to start creating bets
    await token
      .connect(addr1)
      .approve(initiatorDetails.storageAddress, ethers.MaxUint256);
    await initiatorContract
      .connect(addr1)
      .deposit(tokenAddress, ethers.parseEther("1000"));
    await initiatorContract
      .connect(addr1)
      .grantApproval(tokenAddress, betManagementAddress, ethers.MaxUint256);

    // simulate the user approving their storage contract for the first time for that token.
    // then, deposit 1000 tokens into user storage contract.
    // then, approve the bet management contract to start creating bets
    await token
      .connect(addr2)
      .approve(acceptorDetails.storageAddress, ethers.MaxUint256);
    await acceptorContract
      .connect(addr2)
      .deposit(tokenAddress, ethers.parseEther("1000"));
    await acceptorContract
      .connect(addr2)
      .grantApproval(tokenAddress, betManagementAddress, ethers.MaxUint256);

    // deploy the bet
    let tx = await betManagement
      .connect(addr1)
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

  it("Should have the correct bet details", async function () {
    // assert
    expect(await bet.getInitiator()).to.be.equal(initiator);
    expect(await bet.getArbiter()).to.be.equal(arbiter);
    expect(await bet.getStake()).to.be.equal(ethers.parseEther("1000"));
    expect(await bet.getPayout()).to.be.equal(ethers.parseEther("1900"));
    expect(await bet.getPlatformFee()).to.be.equal(ethers.parseEther("50"));
    expect(await bet.getArbiterFee()).to.be.equal(ethers.parseEther("50"));
    expect(await bet.getCondition()).to.be.equal("Condition");
    // assert the bet was added to the user storage contracts
    expect(await initiatorContract.getAllBets()).to.be.lengthOf(1);
    expect(await arbiterContract.getAllBets()).to.be.lengthOf(1);
  });

  it("Should get the bet details", async function () {
    const betDetails = await bet.getBetDetails();
    // assert
    expect(betDetails.initiator.toObject()).to.be.deep.equal(initiatorDetails);
    expect(betDetails.arbiter.toObject()).to.be.deep.equal(arbiterDetails);
    expect(betDetails.stake).to.be.equal(ethers.parseEther("1000"));
    expect(betDetails.payout).to.be.equal(ethers.parseEther("1900"));
    expect(betDetails.platformFee).to.be.equal(ethers.parseEther("50"));
    expect(betDetails.arbiterFee).to.be.equal(ethers.parseEther("50"));
  });

  it("Should allow the acceptor to accept the bet", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // assert
    expect(await token.balanceOf(betAddress)).to.be.equal(ethers.parseEther("2000"));
    expect(await acceptorContract.getAllBets()).to.be.lengthOf(1);
  });

  it("Should allow the arbiter to declare the winner", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(addr3).declareWinner(acceptorDetails, initiatorDetails);
    // assert
    expect(await bet.getStatus()).to.be.equal(3);
    expect(await bet.getWinner()).to.be.equal(acceptorDetails.storageAddress);
    expect(await bet.getLoser()).to.be.equal(initiatorDetails.storageAddress);
    expect(await token.balanceOf(betAddress)).to.be.equal(ethers.parseEther("1900"));
  });

  it("Should allow the winner to withdraw the winnings", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(addr3).declareWinner(acceptorDetails, initiatorDetails);
    // withdraw the winnings
    await bet.connect(addr2).withdrawEarnings();
    // assert
    expect(await bet.getStatus()).to.be.equal(4);
    expect(await token.balanceOf(acceptor)).to.be.equal(ethers.parseEther("1900"));
    expect(await token.balanceOf(arbiter)).to.be.equal(ethers.parseEther("50"));
    expect(await token.balanceOf(betAddress)).to.be.equal(0);
  });

  it("Should allow the initiator to cancel the bet", async function () {
    // cancel the bet
    await bet.connect(addr1).cancelBet();
    // assert
    expect(await bet.getStatus()).to.be.equal(5);
    expect(await token.balanceOf(betAddress)).to.be.equal(0);
    expect(await token.balanceOf(initiator)).to.be.equal(ethers.parseEther("1000"));
  });

  it("Should revert if the initiator tries to declare the winner", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // declare the winner
    await expect(
      bet.connect(addr1).declareWinner(acceptorDetails, arbiterDetails)
    ).to.be.revertedWith("Restricted to arbiter");
  });

  it("Should revert if loser tries to withdraw winnings", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(addr3).declareWinner(acceptorDetails, initiatorDetails);
    // withdraw the winnings
    await expect(bet.connect(addr1).withdrawEarnings()).to.be.revertedWith(
      "Restricted to winner"
    );
  });

  it("Should revert if the arbiter tries to withdraw earnings", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(addr3).declareWinner(acceptorDetails, initiatorDetails);
    // withdraw the winnings
    await expect(bet.connect(addr3).withdrawEarnings()).to.be.revertedWith(
      "Restricted to winner"
    );
  });

  it("Should revert if the multiSig tries to withdraw earnings", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(addr3).declareWinner(acceptorDetails, initiatorDetails);
    // withdraw the winnings
    await expect(bet.connect(multiSig).withdrawEarnings()).to.be.revertedWith(
      "Restricted to winner"
    );
  });

  it("Should revert if the arbiter tries to accept the bet", async function () {
    // accept the bet
    await expect(
      bet.connect(addr3).acceptBet(arbiterDetails)
    ).to.be.revertedWith("Arbiter cannot accept the bet");
  });

  it("Should revert if the acceptor tries to accept the bet again", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // accept the bet again
    await expect(
      bet.connect(addr2).acceptBet(acceptorDetails)
    ).to.be.revertedWith("Bet must be in initiated status");
  });

  it("Should revert if the arbiter tries to cancel the bet", async function () {
    // cancel the bet
    await expect(bet.connect(addr3).cancelBet()).to.be.revertedWith(
      "Restricted to initiator"
    );
  });

  it("Should revert if the acceptor tries to cancel the bet", async function () {
    // accept the bet
    await bet.connect(addr2).acceptBet(acceptorDetails);
    // cancel the bet
    await expect(bet.connect(addr2).cancelBet()).to.be.revertedWith(
      "Restricted to initiator"
    );
  });

  it("Should revert if the multiSig tries to cancel the bet", async function () {
    // cancel the bet
    await expect(bet.connect(multiSig).cancelBet()).to.be.revertedWith(
      "Restricted to initiator"
    );
  });

  it("Should revert if the arbiter tries to declare a winner without the bet being accepted", async function () {
    // declare the winner
    await expect(
      bet.connect(addr3).declareWinner(acceptorDetails, initiatorDetails)
    ).to.be.revertedWith("Bet has not been funded yet");
  });
});
