const { ethers } = require("hardhat");
const fs = require("fs");

async function getUserManagementFixture(multiSig) {
  const userManagement = await ethers.deployContract(
    "UserManagement",
    [multiSig.address],
    multiSig
  );
  return userManagement;
}

async function getBetManagementFixture(multiSig) {
  const betManagement = await ethers.deployContract(
    "BetManagement",
    [multiSig.address],
    multiSig
  );
  return betManagement;
}

async function getDataCenterFixture(multiSig, userManagement, betManagement) {
  const dataCenter = await ethers.deployContract(
    "DataCenter",
    [multiSig.address, userManagement, betManagement],
    multiSig
  );
  return dataCenter;
}

async function getTokenFixture(multiSig) {
  const token = await ethers.deployContract("Vbux", multiSig);
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
