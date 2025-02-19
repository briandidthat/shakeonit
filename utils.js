const { ethers } = require("hardhat");
const fs = require("fs");

async function getUserManagementFixture(multiSig) {
  let userManagement = await ethers.deployContract(
    "UserManagement",
    [multiSig.address],
    multiSig
  );
  userManagement = await userManagement.waitForDeployment();
  return userManagement;
}

async function getBetManagementFixture(multiSig) {
  let betManagement = await ethers.deployContract(
    "BetManagement",
    [multiSig.address],
    multiSig
  );
  betManagement = await betManagement.waitForDeployment();
  return betManagement;
}

async function getDataCenterFixture(multiSig, userManagement, betManagement) {
  let dataCenter = await ethers.deployContract(
    "DataCenter",
    [multiSig.address, userManagement, betManagement],
    multiSig
  );
  dataCenter = await dataCenter.waitForDeployment();
  return dataCenter;
}

async function getTokenFixture(multiSig) {
  let token = await ethers.deployContract("Vbux", multiSig);
  token = await token.waitForDeployment();
  return token;
}

// Helper function to get event object from event name
function getEventObject(target, events) {
  let event = null;
  events.map((element) => {
    // in the event of LOG object, no fragment is present.
    // for shakeonit events, fragment is present and will have a name property
    if (element.fragment) {
      if (element.fragment.name === target) {
        event = element;
      }
    }
  });
  return event;
}

function writeToFile(fileName, content) {
  fs.writeFileSync(fileName, content, (err) => {
    if (err) {
      console.error(err);
      return;
    }
    console.log("File has been created successfully!");
  });
}

module.exports = {
  getEventObject,
  getUserManagementFixture,
  getBetManagementFixture,
  getDataCenterFixture,
  getTokenFixture,
  writeToFile,
};
