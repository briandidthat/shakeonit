const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getDataCenterFixture,
} = require("../utils");

async function main() {
    const [multiSig, initiator, acceptor, arbiter] = ethers.getSigners();


}
