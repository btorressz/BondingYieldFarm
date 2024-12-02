// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./BondingYieldFarm.sol"; 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title BondingYieldFarmTest
/// @notice A test contract to validate the functionality of BondingYieldFarm
contract BondingYieldFarmTest {
    BondingYieldFarm public yieldFarm;
    TestToken public testToken;

    /// @notice Deploy the BondingYieldFarm and TestToken contracts
    constructor() {
        // Deploy a mock ERC20 token for testing
        testToken = new TestToken("Test Token", "TTK", 18, 1_000_000 * 10**18);

        // Deploy the BondingYieldFarm contract
        yieldFarm = new BondingYieldFarm(
            address(testToken), // Address of the mock token
            10,                 // Reward coefficient
            1_000 * 10**18,     // Max deposit per user
            5_000 * 10**18      // Total max liquidity
        );

        // Mint some tokens to this contract for testing
        testToken.mint(address(this), 1_000_000 * 10**18);
    }

    /// @notice Approve and stake tokens into the BondingYieldFarm contract
    /// @param amount The amount of tokens to stake
    function testStake(uint256 amount) external {
        // Approve the yieldFarm contract to spend tokens
        testToken.approve(address(yieldFarm), amount);

        // Stake the tokens
        yieldFarm.stake(amount, false, 0);
    }

    /// @notice Withdraw tokens from the BondingYieldFarm contract
    /// @param amount The amount of tokens to withdraw
    function testWithdraw(uint256 amount) external {
        yieldFarm.withdraw(amount);
    }

    /// @notice Toggle the paused state of the pool
    function testTogglePause() external {
        yieldFarm.togglePause();
    }

    /// @notice Perform an emergency withdrawal
    function testEmergencyWithdraw() external {
        yieldFarm.emergencyWithdraw();
    }

    /// @notice Distribute fees among stakers
    function testDistributeFees() external {
        yieldFarm.distributeFees();
    }
}

/// @title TestToken
/// @dev A simple ERC20 token implementation for testing purposes
contract TestToken is ERC20 {
    address public owner;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        owner = msg.sender;
    }

    /// @notice Mint new tokens (only owner can mint)
    /// @param account The address to receive the minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address account, uint256 amount) external {
        require(msg.sender == owner, "Only owner can mint");
        _mint(account, amount);
    }
}
