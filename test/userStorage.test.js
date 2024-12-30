const { expect } = require("chai");
const { ethers } = require("hardhat");
const { getUserManagementFixture, getTokenFixture } = require("./utils");
const {
  abi,
} = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");

describe("UserStorage", function () {
  let userManagement, userStorage, token;
  let multiSig, addr1, addr2, tokenAddress, userStorageAddress;

  beforeEach(async function () {
    [multiSig, addr1, addr2] = await ethers.getSigners();
    userManagement = await getUserManagementFixture(multiSig.address);
    // Register addr1
    await userManagement.connect(addr1).register();
    // get user strorage address
    userStorageAddress = await userManagement.getUserStorage(addr1.address);
    userStorage = await ethers.getContractAt(abi, userStorageAddress);

    // deploy TestToken
    token = await getTokenFixture(multiSig);
    tokenAddress = await token.getAddress();
    // send 10000 tokens to addr1
    await token.connect(multiSig).transfer(addr1.address, 10000);
    // approve user storage to spend 1000 tokens
    await token.connect(addr1).approve(userStorage, 1000);
  });

  it("Should have deployed UserStorage", async function () {
    let userStorage = await userManagement.getUserStorage(addr1.address);
    expect(userStorage).to.be.a.properAddress;
  });

  it("Should have correct owner", async function () {
    expect(await userStorage.getOwner()).to.equal(addr1.address);
  });

  it("Should deposit to the contract", async function () {
    // deposit 1000 tokens to user storage
    await userStorage.connect(addr1).deposit(tokenAddress, 1000);
    // check balance
    expect(await userStorage.getTokenBalance(tokenAddress)).to.equal(1000);
  });

  it("Should withdraw from the contract", async function () {
    // deposit 1000 tokens to user storage
    await userStorage.connect(addr1).deposit(tokenAddress, 1000);
    // withdraw 500 tokens
    await userStorage.connect(addr1).withdraw(tokenAddress, 500);
    // check balance
    expect(await userStorage.getTokenBalance(tokenAddress)).to.equal(500);
  });

  it("Should grant approval to bet management address", async function () {
    // grant approval to bet management
    await userStorage.connect(addr1).grantApproval(tokenAddress, addr2.address, 1000);
    // check approval
    expect(await token.allowance(userStorageAddress, addr2.address)).to.equal(1000);
  });

  it("Should revert if unauthorized user tries to deposit", async function () {
    // deposit 1000 tokens to user storage
    await expect(
      userStorage.connect(multiSig).deposit(tokenAddress, 1000)
    ).to.be.revertedWith("Restricted to owner");
  });

  it("Should revert if unauthorized user tries to withdraw", async function () {
    // deposit 1000 tokens to user storage
    await userStorage.connect(addr1).deposit(tokenAddress, 1000);
    // withdraw 500 tokens
    await expect(
      userStorage.connect(multiSig).withdraw(tokenAddress, 500)
    ).to.be.revertedWith("Restricted to owner");
  });
});
