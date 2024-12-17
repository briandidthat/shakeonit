const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DataCenter", function () {
    let DataCenter, dataCenter, owner, addr1, addr2, addr3;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        // Deploy the DataCenter contract
        DataCenter = await ethers.getContractFactory("DataCenter");
        dataCenter = await DataCenter.deploy();
        await dataCenter.deployed();
    });

    it("Should deploy the DataCenter contract", async function () {
        expect(dataCenter.address).to.properAddress;
    });

    it("Should set the factory address", async function () {
        await dataCenter.setFactory(addr1.address);
        expect(await dataCenter.factory()).to.equal(addr1.address);
    });

    it("Should block an arbiter", async function () {
        await dataCenter.blockArbiter(addr1.address);
        expect(await dataCenter.isArbiterBlocked(addr1.address)).to.be.true;
    });

    it("Should revert when blocking a zero address arbiter", async function () {
        await expect(dataCenter.blockArbiter(ethers.constants.AddressZero)).to.be.revertedWith("Zero address not allowed");
    });

    it("Should add an arbiter", async function () {
        await dataCenter.addArbiter(addr1.address);
        expect(await dataCenter.isArbiter(addr1.address)).to.be.true;
    });

    it("Should revert when adding a zero address arbiter", async function () {
        await expect(dataCenter.addArbiter(ethers.constants.AddressZero)).to.be.revertedWith("Zero address not allowed");
    });
});