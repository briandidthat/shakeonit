const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BetFactory", function () {
    let BetFactory, betFactory, DataCenter, dataCenter, Bet, bet, owner, addr1, addr2, addr3, token;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        // Deploy a mock ERC20 token for testing
        const Token = await ethers.getContractFactory("MockERC20");
        token = await Token.deploy("Test Token", "TTK", 18, ethers.utils.parseEther("1000"));
        await token.deployed();

        // Deploy the DataCenter contract
        DataCenter = await ethers.getContractFactory("DataCenter");
        dataCenter = await DataCenter.deploy();
        await dataCenter.deployed();

        // Deploy the Bet contract
        Bet = await ethers.getContractFactory("Bet");
        bet = await Bet.deploy();
        await bet.deployed();

        // Deploy the BetFactory contract
        BetFactory = await ethers.getContractFactory("BetFactory");
        betFactory = await BetFactory.deploy(dataCenter.address);
        await betFactory.deployed();

        // Set the factory address in DataCenter
        await dataCenter.setFactory(betFactory.address);
    });

    it("Should deploy the BetFactory contract", async function () {
        expect(betFactory.address).to.properAddress;
    });

    it("Should create a new Bet contract", async function () {
        const tx = await betFactory.createBet(addr1.address, addr2.address, token.address, ethers.utils.parseEther("10"), 1000, "Condition");
        await tx.wait();

        const betAddress = await betFactory.deployedBets(0);
        expect(betAddress).to.properAddress;
    });

    it("Should emit BetCreated event", async function () {
        await expect(betFactory.createBet(addr1.address, addr2.address, token.address, ethers.utils.parseEther("10"), 1000, "Condition"))
            .to.emit(betFactory, "BetCreated")
            .withArgs(
                anyValue, // betAddress
                addr1.address,
                addr2.address,
                token.address,
                ethers.utils.parseEther("10"),
                1000
            );
    });

    it("Should revert if any address is zero", async function () {
        await expect(betFactory.createBet(ethers.constants.AddressZero, addr2.address, token.address, ethers.utils.parseEther("10"), 1000, "Condition"))
            .to.be.revertedWith("Zero address not allowed");

        await expect(betFactory.createBet(addr1.address, ethers.constants.AddressZero, token.address, ethers.utils.parseEther("10"), 1000, "Condition"))
            .to.be.revertedWith("Zero address not allowed");
    });

    it("Should increment instances count", async function () {
        await betFactory.createBet(addr1.address, addr2.address, token.address, ethers.utils.parseEther("10"), 1000, "Condition");
        expect(await betFactory.instances()).to.equal(1);

        await betFactory.createBet(addr1.address, addr2.address, token.address, ethers.utils.parseEther("20"), 2000, "Condition");
        expect(await betFactory.instances()).to.equal(2);
    });
});