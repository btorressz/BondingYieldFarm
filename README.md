# BondingYieldFarm

**Bonding Yield Farm** is a decentralized application (dApp) that enables users to stake ERC20 tokens, earn dynamic rewards based on bonding curve principles, and manage their staked liquidity. This project also has a Solana version written in Rust using the Anchor framework, and it has been translated into an Ethereum-based Solidity implementation. Below, we’ll explore the project, its features, and the key differences between the Solana and Ethereum versions. The project was developed in Remix IDE.


## Features

### 1. Dynamic Yield Farming Rewards
- Rewards are calculated using bonding curves, which incentivize early participation and larger stakes.
  
### 2. Lockup Periods for Rewards Boosting
- Users can set optional lockup periods for their staked tokens to earn additional rewards.

### 3. Anti-Whale Mechanisms
- **Individual User Deposit Limits**: To prevent whales from dominating the pool, there are individual user deposit limits.
- **Total Pool Liquidity Cap**: The total liquidity in the pool has a cap to maintain decentralization and reduce the risk of centralization.

### 4. Fee Distribution
- Withdrawal fees are collected in a fee pool and redistributed proportionally to active stakers.

### 5. Emergency Withdrawal
- Users can withdraw their stakes immediately, bypassing lockup periods, in emergency situations.

### 6. Admin Controls
- **Pool Pause/Unpause**: Admins have the ability to pause or unpause the pool.
- **Fee Distribution**: Admins can control the distribution of the fees.

### 7. Event Transparency
- Events are emitted for all major actions, such as staking, withdrawal, and fee distribution, ensuring transparency.

## Contracts

### 1. **BondingYieldFarm.sol**
- The core smart contract that handles staking, reward calculation, fee management, and withdrawals.
- Written in **Solidity** for the Ethereum Virtual Machine (EVM).
- Handles key operations such as staking, reward distribution, and emergency withdrawals.

### 2. **TestToken.sol** (For Testing)
- A simple **ERC20 token** implementation for testing purposes.
- Mintable and transferable tokens are used to simulate staking operations.

## Key Differences Between Solana and Ethereum Versions

### Solana Version
- **Written in Rust** using the **Anchor Framework**.
  
### Ethereum Version
- **Written in Solidity** for the **Ethereum Virtual Machine (EVM)**.

## How It Works

### Staking
1. Users deposit ERC20 tokens into the `BondingYieldFarm.sol` contract.
2. Rewards are calculated dynamically based on the amount staked and the bonding curve formula.
3. Users can choose to lock their tokens for a defined period to boost their rewards.

### Reward Distribution
1. The rewards are distributed based on the bonding curve, with early and larger stakes receiving higher rewards.
2. The fee pool accumulates withdrawal fees and distributes them proportionally to all active stakers.

### Emergency Withdrawal
- Users can withdraw their staked tokens immediately in case of an emergency, bypassing any lockup periods, though a fee may apply.

### Fee Management
- A small fee is charged on withdrawals, which is then redistributed to active stakers.

## Smart Contract Interaction

Below are the core functions in the `BondingYieldFarm.sol` contract:

### 1. `stake()`
- Function to stake tokens into the farm. Users will receive a reward based on the bonding curve.
  
### 2. `withdraw()`
- Function to withdraw staked tokens and rewards. A withdrawal fee is applied and redistributed to stakers.

### 3. `setLockupPeriod()`
- Allows users to set a lockup period for their staked tokens to boost rewards.

### 4. `emergencyWithdraw()`
- Emergency function to withdraw tokens immediately, bypassing the lockup.

### 5. `pausePool()`
- Admin function to pause the pool in case of issues.

### 6. `unpausePool()`
- Admin function to unpause the pool.

### 7. `distributeFees()`
- Admin function to redistribute accumulated fees to active stakers.

## Conclusion

The **Bonding Yield Farm** provides an innovative way to participate in decentralized finance (DeFi) with dynamic yield farming rewards based on bonding curve principles. The Solana and Ethereum versions cater to different ecosystems but share a common goal: incentivizing early participation and large stakes while maintaining transparency and decentralization.

# License
- This Project is under the **MIT LICENSE**
