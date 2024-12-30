// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const {
//   abi,
// } = require("../artifacts/contracts/UserStorage.sol/UserStorage.json");
// const {
//   abi: betFactoryAbi,
// } = require("../artifacts/contracts/BetFactory.sol/BetFactory.json");
// const { getTokenFixture, getDataCenterFixture } = require("./utils");

// describe("BetFactory", function () {
//   let betFactory, dataCenter;
//   let multiSig, arbiter, addr1, addr2, addr3;

//   beforeEach(async function () {
//     [multiSig, arbiter, addr1, addr2, addr3] = await ethers.getSigners();
//     dataCenter = await getDataCenterFixture(multiSig.address);
//     // get the betFactory contract
//     let betFactoryAddr = await dataCenter.getBetFactory();
//     betFactory = await ethers.getContractAt(betFactoryAbi, betFactoryAddr);
//   });

//   it("Should deploy the BetFactory contract", async function () {
//     expect(await betFactory.getAddress()).to.be.a.properAddress;
//   });

//   it("Should create a new bet", async function () {
//     // register addr1, then get the user storage contract
//     let user = await dataCenter.connect(multiSig).registerUser(addr1.address);
//     let userStorage = await dataCenter.getUserStorage(addr1.address);
//     // create pointer to user storage contract
//     userStorageContract = await ethers.getContractAt(abi, userStorage);

//     // deploy TestToken
//     const token = await getTokenFixture();
//     const tokenAddress = await token.getAddress();

//     // send 10000 tokens to addr1
//     await token.connect(multiSig).transfer(addr1.address, 10000);

//     // approve user storage to spend 1000 tokens
//     await token.connect(addr1).approve(userStorage, 1000);
//     // deposit 1000 tokens to user storage
//     await userStorageContract.connect(addr1).deposit(tokenAddress, 1000);

//     // get the address of the betManagement contract
//     let betManagement = await dataCenter.getBetManagement();
//     // give the betManagement contract permission to spend 1000 tokens
//     await userStorageContract
//       .connect(addr1)
//       .grantApproval(tokenAddress, betManagement, 1000);

//     // deploy a bet
//     let tx = await betFactory
//       .connect(addr1)
//       .deployBet(
//         arbiter.address,
//         tokenAddress,
//         1000,
//         50,
//         50,
//         1900,
//         4133557130,
//         "SOL will be above $1000 on date X"
//       );

//     let betAddress = await tx.wait();
//     console.log(betAddress);

//     expect(await betFactory.getInstances()).to.equal(1);
//     // expect(await betAddress.data).to.be.a.properAddress;
//   });
// });
