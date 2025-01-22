const { ethers } = require("hardhat");
const {
  getUserManagementFixture,
  getBetManagementFixture,
  getDataCenterFixture,
  writeToFile,
} = require("../utils");

async function main() {
  const [multiSig, initiator, acceptor, arbiter] = await ethers.getSigners();

  const userManagement = await getUserManagementFixture(multiSig);
  const userManagementAddress = await userManagement.getAddress();

  const betManagement = await getBetManagementFixture(multiSig);
  const betManagementAddress = await betManagement.getAddress();

  const dataCenter = await getDataCenterFixture(
    multiSig,
    userManagementAddress,
    betManagementAddress
  );
  const dataCenterAddress = await dataCenter.getAddress();

  console.log(`User Management Contract address: ${userManagementAddress}`);
  console.log(`Bet Management contract address: ${betManagementAddress}`);
  console.log(`Data Center contract address: ${dataCenterAddress}`);


  // simulate users registering for the platform
  await userManagement
    .connect(initiator)
    .register("initiator", betManagementAddress);
  await userManagement
    .connect(acceptor)
    .register("acceptor", betManagementAddress);
  await userManagement
    .connect(arbiter)
    .register("arbiter", betManagementAddress);

  // gather initiator details
  const initiatorContractAddress = await userManagement.getUserStorage(
    initiator.address
  );
  const initiatorDetails = {
    owner: initiator.address,
    storageAddress: initiatorContractAddress,
  };
  // gather acceptor details
  const acceptorContractAddress = await userManagement.getUserStorage(
    acceptor.address
  );
  const acceptorDetails = {
    owner: acceptor.address,
    storageAddress: acceptorContractAddress,
  };
  // gather arbiter details
  const arbiterContractAddress = await userManagement.getUserStorage(
    arbiter.address
  );
  const arbiterDetails = {
    owner: arbiter.address,
    storageAddress: arbiterContractAddress,
  };

  console.log(`initiator details: ${JSON.stringify(initiatorDetails)}`);
  console.log(`acceptor details: ${JSON.stringify(acceptorDetails)}`);
  console.log(`arbiter details: ${JSON.stringify(arbiterDetails)}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
