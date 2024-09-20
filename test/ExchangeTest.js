const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange Contract", function () {
    let Token, token, Exchange, exchange;
    let owner, addr1, addr2;
    const tokenSupply = ethers.utils.parseUnits("1000000", 18); // 1,000,000 tokens
    const initialRate = ethers.utils.parseUnits("1000", 18); // Rate: 1000 tokens for 1 ETH

    beforeEach(async function () {
        // Get the ContractFactory and Signers
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy ERC20 Token Contract
        Token = await ethers.getContractFactory("ERC20PresetFixedSupply"); // OpenZeppelin's premade ERC20
        token = await Token.deploy("DevCoin", "DVC", tokenSupply, owner.address);

        // Deploy Exchange Contract
        Exchange = await ethers.getContractFactory("Exchange");
        exchange = await Exchange.deploy(token.address);

        // Transfer some tokens to the exchange contract for testing
        await token.transfer(exchange.address, ethers.utils.parseUnits("500000", 18)); // 500,000 tokens
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await exchange.owner()).to.equal(owner.address);
        });

        it("Should have the correct initial rate", async function () {
            expect(await exchange.rate()).to.equal(initialRate);
        });

        it("Should have the correct token contract address", async function () {
            expect(await exchange.token()).to.equal(token.address);
        });
    });

    describe("Buying Tokens", function () {
        it("Should allow a user to buy tokens", async function () {
            const amountToBuy = ethers.utils.parseUnits("100", 18); // 100 tokens
            const ethToSend = ethers.utils.parseEther("0.1"); // 0.1 ETH

            await exchange.connect(addr1).buyToken(amountToBuy, { value: ethToSend });

            const addr1Balance = await token.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(amountToBuy);
        });

        it("Should revert if insufficient ETH is sent", async function () {
            const amountToBuy = ethers.utils.parseUnits("100", 18); // 100 tokens
            const insufficientEth = ethers.utils.parseEther("0.05"); // 0.05 ETH

            await expect(exchange.connect(addr1).buyToken(amountToBuy, { value: insufficientEth }))
                .to.be.revertedWith("Insufficient ETH sent");
        });
    });

    describe("Selling Tokens", function () {
        it("Should allow a user to sell tokens for ETH", async function () {
            const amountToSell = ethers.utils.parseUnits("100", 18); // 100 tokens
            const ethToReceive = ethers.utils.parseEther("0.1"); // 0.1 ETH

            // Transfer tokens to addr1 and approve the exchange to spend tokens
            await token.transfer(addr1.address, amountToSell);
            await token.connect(addr1).approve(exchange.address, amountToSell);

            // addr1 sells the tokens
            await exchange.connect(addr1).sellToken(amountToSell);

            const addr1EthBalance = await ethers.provider.getBalance(addr1.address);
            expect(addr1EthBalance).to.be.above(ethToReceive); // Should have received ETH
        });

        it("Should revert if the contract has insufficient ETH", async function () {
            const amountToSell = ethers.utils.parseUnits("100000", 18); // A large amount to drain contract ETH
            await token.transfer(addr1.address, amountToSell);
            await token.connect(addr1).approve(exchange.address, amountToSell);

            await expect(exchange.connect(addr1).sellToken(amountToSell))
                .to.be.revertedWith("Insufficient ETH in contract");
        });
    });

    describe("Rate Updates", function () {
        it("Should allow the owner to update the rate", async function () {
            const newRate = ethers.utils.parseUnits("1200", 18); // 1200 tokens per 1 ETH
            await exchange.connect(owner).updateRate(newRate);

            expect(await exchange.rate()).to.equal(newRate);
        });

        it("Should revert if a non-owner tries to update the rate", async function () {
            const newRate = ethers.utils.parseUnits("1200", 18);
            await expect(exchange.connect(addr1).updateRate(newRate))
                .to.be.revertedWith("Caller is not the owner");
        });
    });

    describe("Withdrawals", function () {
        it("Should allow the owner to withdraw ETH from the contract", async function () {
            // Send some ETH to the contract
            await addr1.sendTransaction({ to: exchange.address, value: ethers.utils.parseEther("1") });

            const initialOwnerBalance = await ethers.provider.getBalance(owner.address);
            await exchange.connect(owner).withdrawEth(ethers.utils.parseEther("1"));

            const finalOwnerBalance = await ethers.provider.getBalance(owner.address);
            expect(finalOwnerBalance).to.be.above(initialOwnerBalance);
        });

        it("Should revert if non-owner tries to withdraw ETH", async function () {
            await expect(exchange.connect(addr1).withdrawEth(ethers.utils.parseEther("1")))
                .to.be.revertedWith("Caller is not the owner");
        });
    });
});