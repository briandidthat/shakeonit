const { ethers } = require("hardhat");

async function getUserManagementFixture(multiSig) {
  const userManagement = await ethers.deployContract("UserManagement", [
    multiSig,
  ]);
  return userManagement;
}

async function getBetManagementFixture(multiSig) {
  const betManagement = await ethers.deployContract("BetManagement", [
    multiSig,
  ]);
  return betManagement;
}

async function getDataCenterFixture(multiSig, userManagement, betManagement) {
  const dataCenter = await ethers.deployContract("DataCenter", [
    multiSig,
    userManagement,
    betManagement,
  ]);
  return dataCenter;
}

async function getTokenFixture(multiSig) {
  // deploy TestToken
  const token = await ethers.deployContract(
    "MockERC20",
    ["TestToken", "TTK", 1000000],
    multiSig
  );
  return token;
}

module.exports = {
  getUserManagementFixture,
  getBetManagementFixture,
  getDataCenterFixture,
  getTokenFixture,
};
