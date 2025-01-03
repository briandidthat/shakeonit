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

// Helper function to get event object from event name
function getEventObject(target, events) {
  let event = null;
  events.map((element) => {
    if (element.fragment) {
      if (element.fragment.name === target) {
        event = element;
      }
    }
  });
  return event;
}

module.exports = {
  getEventObject,
  getUserManagementFixture,
  getBetManagementFixture,
  getDataCenterFixture,
  getTokenFixture,
};
