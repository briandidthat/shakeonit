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
        initiator,
        arbiter,
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
});
