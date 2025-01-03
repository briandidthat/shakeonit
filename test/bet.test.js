const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getTokenFixture,
  getEventObject,
} = require("./utils");
const {
  abi: userStorageAbi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");
const { abi: betAbi } = require("../artifacts/contracts/Bet.sol/Bet.json");

describe("Bet", function () {
  let betManagement, userManagement, bet, token;
  let multiSig,
    betManagementAddress,
    tokenAddress,
    initiator,
    acceptor,
    arbiter;
  beforeEach(async function () {
    [multiSig, addr1, addr2, addr3] = await ethers.getSigners();

    betManagement = await getBetManagementFixture(multiSig.address);
    userManagement = await getUserManagementFixture(multiSig.address);
    token = await getTokenFixture(multiSig);
    betManagementAddress = await betManagement.getAddress();

    // register users
    await userManagement.connect(addr1).register(betManagementAddress);
    await userManagement.connect(addr2).register(betManagementAddress);
    await userManagement.connect(addr3).register(betManagementAddress);
    // get user storage addresses
    initiator = await userManagement.getUserStorage(addr1.address);
    acceptor = await userManagement.getUserStorage(addr2.address);
    arbiter = await userManagement.getUserStorage(addr3.address);

    // deploy TestToken
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();
    // send 10000 tokens to initiator
    await token.connect(multiSig).transfer(initiator, 10000);
    // send 10000 tokens to acceptor
    await token.connect(multiSig).transfer(acceptor, 10000);

    // get the initiator's user storage contract (addr1)
    let initiatorContract = await ethers.getContractAt(
      userStorageAbi,
      initiator
    );
    // get the acceptor's user storage contract (addr2)
    let acceptorContract = await ethers.getContractAt(userStorageAbi, acceptor);
    // grant approval rights to the betManagement contract
    await initiatorContract
      .connect(addr1)
      .grantApproval(tokenAddress, betManagementAddress, 1000);
    await acceptorContract
      .connect(addr2)
      .grantApproval(tokenAddress, betManagementAddress, 1000);
    // deploy the bet
    let tx = await betManagement.connect(addr1).deployBet(
      tokenAddress,
      initiator,
      arbiter,
      1000, // stake
      50, // .05% fee for arbiter
      50, // .05% fee for platform
      1900, // payout
      "Condition"
    );
    let receipt = await tx.wait();
    const event = getEventObject("BetCreated", receipt.logs);
    // the first argument of the event is the bet address
    const betAddress = event.args[0];
    // assign pointer to bet address
    bet = await ethers.getContractAt(betAbi, betAddress);
  });

  it("Should have deployed a bet", async function () {
    expect(await betManagement.getBetCount()).to.be.equal(1);
  });

  it("Should have the correct bet details", async function () {
    expect(await bet.getInitiator()).to.be.equal(initiator);
    expect(await bet.getArbiter()).to.be.equal(arbiter);
    expect(await bet.getStake()).to.be.equal(1000);
    expect(await bet.getPayout()).to.be.equal(1900);
    expect(await bet.getPlatformFee()).to.be.equal(50);
    expect(await bet.getArbiterFee()).to.be.equal(50);
    expect(await bet.getCondition()).to.be.equal("Condition");
  });
});
