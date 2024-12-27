// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// describe("Arbiter", function () {
//   let arbiter, bet, token;
//   let multiSig, arbiterManagement, addr1, addr2, addr3;

//   beforeEach(async function () {
//     [multiSig, arbiterManagement, dataCenter, addr1, addr2, addr3] =
//       await ethers.getSigners();

//     // Deploy a mock ERC20 token for testing
//     token = await ethers.deployContract("MockERC20", ["Test Token", "TTK", 18, ethers.parseEther("1000")]);

//     // Deploy the Bet contract
//     bet = await ethers.deployContract("Bet");

//     // Deploy the Arbiter contract
//     arbiter = await ethers.deployContract("Arbiter", [
//       multiSig.address,
//       arbiterManagement.address,
//     ]);
//   });

//   it("Should deploy the Arbiter contract", async function () {
//     expect(await arbiter.getAddress()).to.be.a.properAddress;
//   });
// });
