# Smart Lottery Contract

A decentralized and verifiably random lottery system built with Solidity and Chainlink VRF.

## Overview

SmartLottery is a decentralized lottery system that allows users to:
- Create and participate in multiple concurrent lottery instances
- Enter lotteries by purchasing tickets
- Have winners selected automatically and fairly using Chainlink's Verifiable Random Function (VRF)
- Operate lotteries with customizable parameters like ticket price and expiration time

## Key Features

- **Multiple Concurrent Lotteries**: Support for running multiple lottery instances simultaneously
- **Verifiable Randomness**: Uses Chainlink VRF for provably fair winner selection
- **Customizable Parameters**: Configurable ticket prices and expiration times
- **Role-Based Access**: Lottery operators have special privileges for managing their lotteries
- **Automated Winner Selection**: Winners are selected and paid out automatically
- **Gas Efficient**: Optimized for minimal gas consumption

## Contract Architecture

The system consists of the following main components:

- `SmartLottery.sol`: The main contract handling lottery logic
- `HelperConfig.sol`: Configuration helper for different networks
- `DeployLottery.s.sol`: Deployment script

## Technical Details

### Key Dependencies
- Solidity ^0.8.20
- Chainlink VRF V2 Plus
- Foundry for development and testing

### Network Configurations
- Supports Sepolia testnet and local development
- Configurable VRF parameters per network

## Development

### Prerequisites
- Foundry
- Chainlink VRF Subscription (for live networks)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/smart-lottery
   cd smart-lottery
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Build the project:
   ```bash
   forge build
   ```

4. Run tests:
   ```bash
   forge test
   ```
