// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/exchange.sol"; // Path to your Exchange contract
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract ExchangeTest {
    Exchange exchange;
    ERC20PresetFixedSupply token;

    address owner;
    address addr1;
    address addr2;

    uint256 tokenSupply = 1000000 * 1e18; // 1,000,000 tokens
    uint256 initialRate = 1000 * 1e18;    // Rate: 1000 tokens per 1 ETH

    // Runs before each test
    function beforeEach() public {
        // Set up two test accounts
        owner = address(this); // Current contract is the owner
        addr1 = address(0x123);
        addr2 = address(0x456);

        // Deploy token contract and exchange contract
        token = new ERC20PresetFixedSupply("DevCoin", "DVC", tokenSupply, owner);
        exchange = new Exchange(address(token));

        // Transfer some tokens to the exchange contract for testing
        token.transfer(address(exchange), 500000 * 1e18); // 500,000 tokens
    }

    function testBuyToken() public payable {
        uint256 amountToBuy = 100 * 1e18; // 100 tokens
        uint256 ethToSend = 0.1 ether;    // 0.1 ETH

        // Simulate buying tokens
        exchange.buyToken{ value: ethToSend }(amountToBuy);

        uint256 balance = token.balanceOf(address(this));
        require(balance == amountToBuy, "Should have bought 100 tokens");
    }


    /// @dev Test if only the owner can update the rate
    function testUpdateRate() public {
        uint256 newRate = 1200 * 1e18; // New rate: 1200 tokens per 1 ETH

        // Attempt to update the rate
        exchange.updateRate(newRate);
        Assert.equal(exchange.rate(), newRate, "Rate should be updated to 1200 tokens per 1 ETH");
    }

    /// @dev Test if the contract can reject non-owner rate updates
    function testNonOwnerCannotUpdateRate() public {
        bool success = false;
        try exchange.updateRate(500 * 1e18) {
            success = true;
        } catch {
            success = false;
        }
        Assert.equal(success, false, "Non-owner should not be able to update the rate");
    }

    /// @dev Test if the owner can withdraw ETH from the contract
    function testWithdrawEth() public payable {
        uint256 ethToDeposit = 1 ether; // Send 1 ETH to the exchange contract
        payable(address(exchange)).transfer(ethToDeposit);

        // Check contract balance before withdrawal
        uint256 contractBalanceBefore = address(exchange).balance;
        Assert.equal(contractBalanceBefore, ethToDeposit, "Contract should have 1 ETH");

        // Withdraw ETH
        exchange.withdrawEth(ethToDeposit);

        uint256 contractBalanceAfter = address(exchange).balance;
        Assert.equal(contractBalanceAfter, 0, "Contract balance should be 0 after withdrawal");
    }

    /// @dev Test emergency token withdrawal by the owner
    function testEmergencyTokenWithdraw() public {
        uint256 contractTokenBalanceBefore = token.balanceOf(address(exchange));
        Assert.equal(contractTokenBalanceBefore, 500000 * 1e18, "Contract should hold 500,000 tokens");

        // Perform emergency token withdrawal
        exchange.emergencyTokenWithdraw();

        uint256 contractTokenBalanceAfter = token.balanceOf(address(exchange));
        Assert.equal(contractTokenBalanceAfter, 0, "Contract should hold 0 tokens after emergency withdrawal");
    }
}