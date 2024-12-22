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
        dataCenter = await DataCenter.deploy(owner.address);
        await dataCenter.deployed();

        // Deploy the BetFactory contract
        BetFactory = await ethers.getContractFactory("BetFactory");
        betFactory = await BetFactory.deploy(owner.address);
        await betFactory.deployed();

        // Deploy the Bet contract
        bet = await betFactory.deployBet()
    });

    it("Should deploy the BetFactory contract", async function () {
        expect(betFactory.address).to.properAddress;
    });

    it("Should create a new Bet contract", async function () {
        await betFactory.register();
        const tx = await betFactory.deployBet(
            addr1.address,
            token.address,
            ethers.utils.parseEther("10"),
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("0.5"),
            Math.floor(Date.now() / 1000) + 3600,
            "Condition"
        );
        await tx.wait();

        const betAddress = await dataCenter.deployedBets(0);
        expect(betAddress).to.properAddress;
    });

    it("Should emit BetCreated event", async function () {
        await betFactory.register();
        await expect(betFactory.deployBet(
            addr1.address,
            token.address,
            ethers.utils.parseEther("10"),
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("0.5"),
            Math.floor(Date.now() / 1000) + 3600,
            "Condition"
        ))
            .to.emit(betFactory, "BetCreated")
            .withArgs(
                anyValue, // betAddress
                owner.address,
                addr1.address,
                token.address,
                ethers.utils.parseEther("10"),
                Math.floor(Date.now() / 1000) + 3600
            );
    });

    it("Should revert if any address is zero", async function () {
        await betFactory.register();
        await expect(betFactory.deployBet(
            ethers.constants.AddressZero,
            token.address,
            ethers.utils.parseEther("10"),
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("0.5"),
            Math.floor(Date.now() / 1000) + 3600,
            "Condition"
        ))
            .to.be.revertedWith("Zero address not allowed");

        await expect(betFactory.deployBet(
            addr1.address,
            ethers.constants.AddressZero,
            ethers.utils.parseEther("10"),
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("0.5"),
            Math.floor(Date.now() / 1000) + 3600,
            "Condition"
        ))
            .to.be.revertedWith("Zero address not allowed");
    });

    it("Should increment instances count", async function () {
        await betFactory.register();
        await betFactory.deployBet(
            addr1.address,
            token.address,
            ethers.utils.parseEther("10"),
            ethers.utils.parseEther("1"),
            ethers.utils.parseEther("0.5"),
            Math.floor(Date.now() / 1000) + 3600,
            "Condition"
        );
        expect(await betFactory.instances()).to.equal(1);

        await betFactory.deployBet(
            addr1.address,
            token.address,
            ethers.utils.parseEther("20"),
            ethers.utils.parseEther("2"),
            ethers.utils.parseEther("1"),
            Math.floor(Date.now() / 1000) + 7200,
            "Condition"
        );
        expect(await betFactory.instances()).to.equal(2);
    });

    it("Should register a new user", async function () {
        const userStorageAddress = await betFactory.register();
        expect(userStorageAddress).to.properAddress;
    });

    it("Should return the implementation address", async function () {
        const implementationAddress = await betFactory.getImplementation();
        expect(implementationAddress).to.equal(await betFactory.implementation());
    });
});