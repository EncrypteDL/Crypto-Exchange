// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Exchange {
    using SafeMath for uint256;

    address public owner;
    uint256 public creationTime;
    uint256 public constant ICO_RATE = 1000 * 1e18; // tokens for 1 ETH
    uint256 public rate; // dynamic rate for tokens per ETH
    IERC20 public token;

    event BuyToken(address indexed user, uint256 amount, uint256 costWei, uint256 balance);
    event SellToken(address indexed user, uint256 amount, uint256 costWei, uint256 balance);
    event RateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
    * @dev Constructor initializes the exchange with the token contract and owner.
    */
    constructor(address tokenContractAddr) {
        require(tokenContractAddr != address(0), "Invalid token contract address");
        token = IERC20(tokenContractAddr);
        owner = msg.sender;
        creationTime = block.timestamp; // use block.timestamp instead of now (deprecated)
        rate = ICO_RATE;
    }

    /**
    * @dev Fallback function to load the contract with ether.
    */
    receive() external payable {}

    /**
    * @dev Buy a specified amount of tokens by sending ETH.
    */
    function buyToken(uint256 amount) external payable returns (bool success) {
        uint256 costWei = amount.mul(1 ether).div(rate);
        require(msg.value >= costWei, "Insufficient ETH sent");

        uint256 contractTokenBalance = token.balanceOf(address(this));
        require(contractTokenBalance >= amount, "Not enough tokens in contract");

        token.transfer(msg.sender, amount);
        emit BuyToken(msg.sender, amount, costWei, token.balanceOf(msg.sender));

        // Send back any excess ETH
        uint256 excess = msg.value.sub(costWei);
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }

        return true;
    }

    /**
    * @dev Sell a specified amount of tokens to get ETH back.
    */
    function sellToken(uint256 amount) external returns (bool success) {
        uint256 costWei = amount.mul(1 ether).div(rate);
        require(address(this).balance >= costWei, "Insufficient ETH in contract");

        require(token.allowance(msg.sender, address(this)) >= amount, "Token allowance too low");
        token.transferFrom(msg.sender, address(this), amount);

        payable(msg.sender).transfer(costWei);
        emit SellToken(msg.sender, amount, costWei, token.balanceOf(msg.sender));

        return true;
    }

    /**
    * @dev Update the token exchange rate, only callable by the owner.
    */
    function updateRate(uint256 newRate) external onlyOwner returns (bool success) {
        require(newRate >= ICO_RATE, "New rate must be greater than or equal to ICO rate");
        rate = newRate;
        emit RateUpdated(newRate);
        return true;
    }

    /**
    * @dev Withdraw any excess ETH from the contract, only callable by the owner.
    */
    function withdrawEth(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner).transfer(amount);
    }

    /**
    * @dev Emergency withdrawal of all contract tokens, only callable by the owner.
    */
    function emergencyTokenWithdraw() external onlyOwner {
        uint256 contractTokenBalance = token.balanceOf(address(this));
        token.transfer(owner, contractTokenBalance);
    }
}
