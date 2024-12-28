const { ethers } = require("hardhat");

async function getArbiterManagementFixture(multiSig) {
  const arbiterManagement = await ethers.deployContract("ArbiterManagement", [
    multiSig,
  ]);
  return arbiterManagement;
}

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

async function getArbiterFixture(multiSig, arbiterManagement) {
  const arbiter = await ethers.deployContract("Arbiter", [
    multiSig,
    arbiterManagement,
  ]);
  return arbiter;
}

async function getDataCenterFixture(multiSig) {
  const dataCenter = await ethers.deployContract("DataCenter", [multiSig]);
  return dataCenter;
}

async function getFactoryFixture(multiSig, dataCenter) {
  const factory = await ethers.deployContract("Factory", [
    multiSig,
    dataCenter,
  ]);
  return factory;
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
  getArbiterManagementFixture,
  getBetManagementFixture,
  getArbiterFixture,
  getDataCenterFixture,
  getFactoryFixture,
  getTokenFixture,
};
