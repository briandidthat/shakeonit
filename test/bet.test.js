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
    initiatorContractAddress,
    acceptorContractAddress,
    arbiterContractAddress,
    betAddress;
  beforeEach(async function () {
    [multiSig, initiator, acceptor, arbiter] = await ethers.getSigners();
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
      .connect(initiator)
      .register("initiator", betManagementAddress);
    await userManagement
      .connect(acceptor)
      .register("acceptor", betManagementAddress);
    await userManagement
      .connect(arbiter)
      .register("arbiter", betManagementAddress);
    // get user storage addresses
    initiatorContractAddress = await userManagement.getUserStorage(
      initiator.address
    );
    acceptorContractAddress = await userManagement.getUserStorage(
      acceptor.address
    );
    arbiterContractAddress = await userManagement.getUserStorage(
      arbiter.address
    );
    // create user details objects
    initiatorDetails = {
      owner: initiator.address,
      storageAddress: initiatorContractAddress,
    };
    acceptorDetails = {
      owner: acceptor.address,
      storageAddress: acceptorContractAddress,
    };
    arbiterDetails = {
      owner: arbiter.address,
      storageAddress: arbiterContractAddress,
    };

    // send 1000 tokens to initiatorContractAddress
    await token
      .connect(multiSig)
      .transfer(initiator.address, ethers.parseEther("1000"));
    // send 1000 tokens to acceptorContractAddress
    await token
      .connect(multiSig)
      .transfer(acceptor.address, ethers.parseEther("1000"));

    // get the initiator's user storage contract (initiator)
    initiatorContract = await ethers.getContractAt(
      userStorageAbi,
      initiatorContractAddress
    );
    // get the acceptor's user storage contract (acceptor)
    acceptorContract = await ethers.getContractAt(
      userStorageAbi,
      acceptorContractAddress
    );
    // get the arbiter's user storage contract (arbiter)
    arbiterContract = await ethers.getContractAt(
      userStorageAbi,
      arbiterContractAddress
    );

    // simulate the user approving their storage contract for the first time for that token.
    // then, deposit 1000 tokens into user storage contract.
    await token
      .connect(initiator)
      .approve(initiatorDetails.storageAddress, ethers.MaxUint256);
    await initiatorContract
      .connect(initiator)
      .deposit(tokenAddress, ethers.parseEther("1000"));

    // simulate the user approving their storage contract for the first time for that token.
    // then, deposit 1000 tokens into user storage contract.
    await token
      .connect(acceptor)
      .approve(acceptorDetails.storageAddress, ethers.MaxUint256);
    await acceptorContract
      .connect(acceptor)
      .deposit(tokenAddress, ethers.parseEther("1000"));

    // deploy the bet
    let tx = await betManagement.connect(initiator).deployBet({
      token: tokenAddress,
      initiator: initiatorDetails,
      arbiter: arbiterDetails,
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

  it("Should have the correct bet details", async function () {
    // assert
    expect(await bet.getInitiator()).to.be.equal(initiatorContractAddress);
    expect(await bet.getArbiter()).to.be.equal(arbiterContractAddress);
    expect(await bet.getStake()).to.be.equal(ethers.parseEther("1000"));
    expect(await bet.getPayout()).to.be.equal(ethers.parseEther("1900"));
    expect(await bet.getPlatformFee()).to.be.equal(ethers.parseEther("50"));
    expect(await bet.getArbiterFee()).to.be.equal(ethers.parseEther("50"));
    expect(await bet.getCondition()).to.be.equal("Condition");
    // assert the bet was added to the user storage contracts
    expect(await initiatorContract.getBets()).to.be.lengthOf(1);
    expect(await arbiterContract.getBets()).to.be.lengthOf(1);
  });

  it("Should get the bet details", async function () {
    const betDetails = await bet.getBetDetails();
    // assert
    expect(betDetails.betContract).to.be.equal(betAddress);
    expect(betDetails.token).to.be.equal(tokenAddress);

    expect(betDetails.initiator.toObject()).to.be.deep.equal(initiatorDetails);
    expect(betDetails.arbiter.toObject()).to.be.deep.equal(arbiterDetails);
    // acceptor is not set yet, same for winner and loser
    expect(betDetails.acceptor.toObject()).to.be.deep.equal({
      owner: ethers.ZeroAddress,
      storageAddress: ethers.ZeroAddress,
    });
    expect(betDetails.winner).to.be.equal(ethers.ZeroAddress);
    expect(betDetails.loser).to.be.equal(ethers.ZeroAddress);
    expect(betDetails.status).to.be.equal(1);
    expect(betDetails.stake).to.be.equal(ethers.parseEther("1000"));
    expect(betDetails.payout).to.be.equal(ethers.parseEther("1900"));
    expect(betDetails.platformFee).to.be.equal(ethers.parseEther("50"));
    expect(betDetails.arbiterFee).to.be.equal(ethers.parseEther("50"));
  });

  it("Should allow the acceptor to accept the bet", async function () {
    // accept the bet
    await bet.connect(acceptor).acceptBet(acceptorDetails);
    // assert
    expect(await token.balanceOf(betAddress)).to.be.equal(
      ethers.parseEther("2000")
    );
    expect(await bet.getStatus()).to.be.equal(2);
    expect(await bet.getAcceptor()).to.be.equal(acceptorContractAddress);
    expect(await acceptorContract.getBets()).to.be.lengthOf(1);
  });

  it("Should allow the arbiter to declare the winner", async function () {
    // accept the bet
    await bet.connect(acceptor).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(arbiter).declareWinner(acceptorDetails, initiatorDetails);
    // assert
    expect(await bet.getStatus()).to.be.equal(3);
    expect(await bet.getWinner()).to.be.equal(acceptorDetails.storageAddress);
    expect(await bet.getLoser()).to.be.equal(initiatorDetails.storageAddress);
    expect(await token.balanceOf(betAddress)).to.be.equal(
      ethers.parseEther("1900")
    );
  });

  it("Should allow the winner to withdraw the winnings", async function () {
    // accept the bet
    await bet.connect(acceptor).acceptBet(acceptorDetails);
    // declare the winner
    await bet.connect(arbiter).declareWinner(acceptorDetails, initiatorDetails);
    // withdraw the winnings
    await bet.connect(acceptor).withdrawEarnings();
    // assert
    expect(await bet.getStatus()).to.be.equal(4);
    expect(await token.balanceOf(acceptorContractAddress)).to.be.equal(
      ethers.parseEther("1900")
    );
    expect(await token.balanceOf(arbiterContractAddress)).to.be.equal(
      ethers.parseEther("50")
    );
    expect(await token.balanceOf(betAddress)).to.be.equal(0);
  });

  it("Should allow the initiator to cancel the bet", async function () {
    // cancel the bet
    await bet.connect(initiator).cancelBet();
    // assert
    expect(await bet.getStatus()).to.be.equal(5);
    expect(await token.balanceOf(betAddress)).to.be.equal(0);
    expect(await token.balanceOf(initiatorContractAddress)).to.be.equal(
      ethers.parseEther("1000")
    );
  });

  describe("View Functions", function () {
    it("Should return the correct bet status", async function () {
      // assert
      expect(await bet.getStatus()).to.be.equal(1);
    });

    it("Should return the correct bet participants", async function () {
      // assert
      expect(await bet.getInitiator()).to.be.equal(initiatorContractAddress);
      expect(await bet.getAcceptor()).to.be.equal(ethers.ZeroAddress);
      expect(await bet.getArbiter()).to.be.equal(arbiterContractAddress);
    });

    it("should return a bets array of length 1 for all participants", async function () {
      const arbiterBets = await arbiterContract.getBets();
      const initiatorBets = await initiatorContract.getBets();

      expect(arbiterBets).to.be.lengthOf(1);
      expect(initiatorBets).to.be.lengthOf(1);
    });
  });

  describe("Error Handling", function () {
    it("Should revert is user tries to update bet balance", async function () {
      await expect(
        bet
          .connect(initiator)
          .updateBalance(tokenAddress, ethers.parseEther("10"))
      ).to.be.revertedWith("Restricted to bet mgmt");
    });
    it("Should revert if the initiatorContractAddress tries to declare the winner", async function () {
      // accept the bet
      await bet.connect(acceptor).acceptBet(acceptorDetails);
      // declare the winner
      await expect(
        bet.connect(initiator).declareWinner(acceptorDetails, arbiterDetails)
      ).to.be.revertedWith("Restricted to arbiter");
    });

    it("Should revert if loser tries to withdraw winnings", async function () {
      // accept the bet
      await bet.connect(acceptor).acceptBet(acceptorDetails);
      // declare the winner
      await bet
        .connect(arbiter)
        .declareWinner(acceptorDetails, initiatorDetails);
      // withdraw the winnings
      await expect(
        bet.connect(initiator).withdrawEarnings()
      ).to.be.revertedWith("Restricted to winner");
    });

    it("Should revert if the arbiter tries to withdraw earnings", async function () {
      // accept the bet
      await bet.connect(acceptor).acceptBet(acceptorDetails);
      // declare the winner
      await bet
        .connect(arbiter)
        .declareWinner(acceptorDetails, initiatorDetails);
      // withdraw the winnings
      await expect(bet.connect(arbiter).withdrawEarnings()).to.be.revertedWith(
        "Restricted to winner"
      );
    });

    it("Should revert if the multiSig tries to withdraw earnings", async function () {
      // accept the bet
      await bet.connect(acceptor).acceptBet(acceptorDetails);
      // declare the winner
      await bet
        .connect(arbiter)
        .declareWinner(acceptorDetails, initiatorDetails);
      // withdraw the winnings
      await expect(bet.connect(multiSig).withdrawEarnings()).to.be.revertedWith(
        "Restricted to winner"
      );
    });

    it("Should revert if the arbiter tries to accept the bet", async function () {
      // accept the bet
      await expect(
        bet.connect(arbiter).acceptBet(arbiterDetails)
      ).to.be.revertedWith("Arbiter cannot accept the bet");
    });

    it("Should revert if the acceptor tries to accept the bet again", async function () {
      // accept the bet
      await bet.connect(acceptor).acceptBet(acceptorDetails);
      // accept the bet again
      await expect(
        bet.connect(acceptor).acceptBet(acceptorDetails)
      ).to.be.revertedWith("Bet must be in initiated status");
    });

    it("Should revert if the arbiter tries to cancel the bet", async function () {
      // cancel the bet
      await expect(bet.connect(arbiter).cancelBet()).to.be.revertedWith(
        "Restricted to initiator"
      );
    });

    it("Should revert if the acceptor tries to cancel the bet", async function () {
      // accept the bet
      await bet.connect(acceptor).acceptBet(acceptorDetails);
      // cancel the bet
      await expect(bet.connect(acceptor).cancelBet()).to.be.revertedWith(
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
        bet.connect(arbiter).declareWinner(acceptorDetails, initiatorDetails)
      ).to.be.revertedWith("Bet has not been funded yet");
    });
  });
});
