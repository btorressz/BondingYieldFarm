// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Bonding Yield Farm Contract
/// @dev A staking contract for yield farming with rewards and withdrawal fees. This contract supports emergency withdrawal, rewards calculation, and fee distribution.
contract BondingYieldFarm is Ownable {
    /// @notice Struct representing the details of each staking pool.
    struct Pool {
        IERC20 token; // Token used for staking and rewards
        uint256 totalLiquidity; // Total liquidity (stake) in the pool
        uint256 rewardCoefficient; // Coefficient for calculating rewards based on staked amount and time
        uint256 feeRate; // Withdrawal fee rate (in percentage, e.g., 2 for 2%)
        uint256 lastUpdate; // Timestamp of the last pool update (used in reward calculation)
        address topStaker; // Address of the top staker with the most staked amount
        uint256 topStakerAmount; // Amount staked by the top staker
        uint256 totalRewardsDistributed; // Total rewards distributed to stakers
        uint256 maxDepositPerUser; // Maximum deposit allowed per user
        uint256 totalMaxLiquidity; // Maximum total liquidity allowed in the pool
        bool isPaused; // State flag for pausing the pool (can be toggled by the owner)
    }

    /// @notice Struct representing the position of a user in the pool (i.e., their staked amount, reward, and lockup details).
    struct UserPosition {
        uint256 amount; // Amount of tokens staked by the user
        uint256 stakeTime; // Timestamp when the stake was made
        uint256 unlockTime; // Timestamp when the user's stake can be withdrawn
        uint256 feeShare; // Share of the accumulated fee pool (in case of fee distribution)
    }

    Pool public pool; // Pool instance containing the overall pool state
    mapping(address => UserPosition) public userPositions; // Mapping to store each user's staking position
    address[] public stakers; // Array to track the list of stakers
    uint256 public feePool; // Total accumulated fees for distribution to users

    // Events emitted for important actions
    event PoolInitialized(address indexed token, uint256 rewardCoefficient, uint256 maxDepositPerUser, uint256 totalMaxLiquidity);
    event Staked(address indexed user, uint256 amount, uint256 rewards, bool autoCompounded);
    event Withdrawn(address indexed user, uint256 amount, uint256 fee, uint256 timestamp);
    event FeesDistributed(uint256 totalFees);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event PoolPaused(bool isPaused);

    /// @notice Modifier to ensure the pool is not paused when executing certain functions.
    modifier poolNotPaused() {
        require(!pool.isPaused, "Pool is paused"); // Prevent any action if the pool is paused
        _;
    }

    /// @notice Modifier to ensure the amount being staked or withdrawn is greater than zero.
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    /// @notice Constructor to initialize the contract with initial parameters
    /// @param _token The ERC20 token used for staking
    /// @param _rewardCoefficient The coefficient used to calculate rewards
    /// @param _maxDepositPerUser Maximum amount a user can deposit into the pool
    /// @param _totalMaxLiquidity Maximum total liquidity allowed in the pool
    constructor(
        address _token,
        uint256 _rewardCoefficient,
        uint256 _maxDepositPerUser,
        uint256 _totalMaxLiquidity
    ) Ownable(msg.sender) { // Explicitly passing msg.sender to Ownable constructor for clarity
        pool.token = IERC20(_token); // Set the ERC20 token for staking
        pool.rewardCoefficient = _rewardCoefficient; // Set the reward coefficient
        pool.maxDepositPerUser = _maxDepositPerUser; // Set the max deposit per user
        pool.totalMaxLiquidity = _totalMaxLiquidity; // Set the max liquidity for the pool
        pool.feeRate = 2; // Default fee rate is 2% (can be modified)
        pool.lastUpdate = block.timestamp; // Set the last update time to the current block timestamp
        pool.isPaused = false; // The pool is not paused initially

        emit PoolInitialized(_token, _rewardCoefficient, _maxDepositPerUser, _totalMaxLiquidity);
    }

    /// @notice Stake a certain amount of tokens into the pool and optionally auto-compound rewards.
    /// @param amount The amount of tokens to stake
    /// @param autoCompound Whether to auto-compound the rewards or not
    /// @param lockupPeriod The lockup period in seconds, which determines when the stake can be withdrawn
    function stake(uint256 amount, bool autoCompound, uint256 lockupPeriod)
        external
        poolNotPaused
        validAmount(amount)
    {
        UserPosition storage userPosition = userPositions[msg.sender];

        require(userPosition.amount + amount <= pool.maxDepositPerUser, "Deposit exceeds user limit"); // Ensure the user doesn't exceed their deposit limit
        require(pool.totalLiquidity + amount <= pool.totalMaxLiquidity, "Pool liquidity exceeded"); // Ensure the total pool liquidity is not exceeded

        if (userPosition.amount == 0) {
            stakers.push(msg.sender); // Add the user to the staker list if they are staking for the first time
        }

        // Update the user's stake details
        userPosition.amount += amount;
        userPosition.stakeTime = block.timestamp; // Set the stake time to the current block timestamp
        if (lockupPeriod > 0) {
            userPosition.unlockTime = block.timestamp + lockupPeriod; // Set unlock time if lockup period is specified
        }

        pool.totalLiquidity += amount; // Increase the total liquidity in the pool

        // Calculate the rewards for the user, based on their stake amount, stake time, and the pool's reward coefficient
        uint256 reward = calculateBoostedReward(userPosition.amount, userPosition.stakeTime, pool.lastUpdate, pool.rewardCoefficient);
        
        if (autoCompound) {
            userPosition.amount += reward; // Compound the rewards into the user's stake if auto-compounding is enabled
        } else {
            pool.token.transfer(msg.sender, reward); // Otherwise, transfer the rewards to the user directly
        }

        pool.totalRewardsDistributed += reward; // Update the total rewards distributed by the pool

        // Track the top staker based on the staked amount
        if (userPosition.amount > pool.topStakerAmount) {
            pool.topStaker = msg.sender;
            pool.topStakerAmount = userPosition.amount;
        }

        pool.token.transferFrom(msg.sender, address(this), amount); // Transfer the staked tokens from the user to the contract

        emit Staked(msg.sender, amount, reward, autoCompound); // Emit the staking event
    }

    /// @notice Withdraw a specified amount of tokens from the pool, subject to withdrawal fees and lockup periods.
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount)
        external
        poolNotPaused
        validAmount(amount)
    {
        UserPosition storage userPosition = userPositions[msg.sender];
        require(userPosition.amount >= amount, "Insufficient balance"); // Ensure the user has enough staked tokens
        require(block.timestamp >= userPosition.unlockTime, "Stake is still locked"); // Ensure the stake is unlocked

        uint256 fee = (amount * pool.feeRate) / 100; // Calculate the fee for the withdrawal
        uint256 netAmount = amount - fee; // Subtract the fee from the amount to be withdrawn

        userPosition.amount -= amount; // Decrease the user's staked amount
        pool.totalLiquidity -= amount; // Decrease the total pool liquidity
        feePool += fee; // Accumulate the withdrawal fee into the fee pool

        if (userPosition.amount == 0) {
            removeStaker(msg.sender); // Remove the user from the staker list if they have withdrawn all funds
        }

        pool.token.transfer(msg.sender, netAmount); // Transfer the net amount (after fee) to the user

        emit Withdrawn(msg.sender, netAmount, fee, block.timestamp); // Emit the withdrawal event
    }

    /// @notice Toggle the paused state of the pool (only callable by the owner).
    function togglePause() external onlyOwner {
        pool.isPaused = !pool.isPaused; // Flip the paused state of the pool
        emit PoolPaused(pool.isPaused); // Emit the pool paused event
    }

    /// @notice Calculate the boosted rewards based on the staked amount, stake time, last update time, and the pool's reward coefficient.
    /// @param amount The amount of tokens staked
    /// @param stakeTime The timestamp when the stake was made
    /// @param lastUpdate The timestamp of the last pool update
    /// @param rewardCoefficient The coefficient used to calculate rewards
    function calculateBoostedReward(
        uint256 amount,
        uint256 stakeTime,
        uint256 lastUpdate,
        uint256 rewardCoefficient
    ) public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - lastUpdate; // Calculate the elapsed time since the last update
        uint256 timeMultiplier = 100 + (elapsedTime / 1 days); // Use time-based multiplier for rewards (rewards increase over time)
        uint256 amountMultiplier = 100 + (amount / 1000); // Use amount-based multiplier (larger stakes get more rewards)
        return (amount * timeMultiplier * amountMultiplier * rewardCoefficient) / 10000; // Calculate the final boosted reward
    }

    /// @notice Distribute accumulated fees to all stakers proportionally to their stake amounts.
    function distributeFees() external onlyOwner {
        uint256 totalFees = feePool;
        require(totalFees > 0, "No fees to distribute"); // Ensure there are fees to distribute

        // Distribute the accumulated fees to each staker
        for (uint256 i = 0; i < stakers.length; i++) {
            address user = stakers[i];
            UserPosition storage userPosition = userPositions[user];
            uint256 userShare = (userPosition.amount * totalFees) / pool.totalLiquidity; // Calculate each user's share of the fees
            userPosition.feeShare += userShare; // Add the share to the user's fee pool
        }

        feePool = 0; // Reset the fee pool after distribution

        emit FeesDistributed(totalFees); // Emit the event for fee distribution
    }

    /// @notice Allow a user to withdraw their entire stake immediately in an emergency (bypassing lockups and fees).
    function emergencyWithdraw() external {
        UserPosition storage userPosition = userPositions[msg.sender];
        require(userPosition.amount > 0, "Nothing to withdraw"); // Ensure the user has staked tokens to withdraw

        uint256 amount = userPosition.amount;
        userPosition.amount = 0; // Reset the user's stake amount to zero
        pool.totalLiquidity -= amount; // Decrease the pool's total liquidity

        removeStaker(msg.sender); // Remove the user from the staker list

        pool.token.transfer(msg.sender, amount); // Transfer the entire stake amount back to the user

        emit EmergencyWithdrawal(msg.sender, amount); // Emit the emergency withdrawal event
    }

    /// @notice Internal function to remove a user from the staker list when they have withdrawn their entire stake.
    /// @param staker The address of the staker to be removed
    function removeStaker(address staker) internal {
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakers[i] == staker) {
                stakers[i] = stakers[stakers.length - 1]; // Replace the staker to be removed with the last one
                stakers.pop(); // Remove the last element from the array
                break;
            }
        }
    }

    /// @notice Get the list of all stakers in the pool.
    /// @return stakers List of staker addresses
    function getStakers() external view returns (address[] memory) {
        return stakers; // Return the array of staker addresses
    }
}
