# Beeezo RewardDistributor Smart Contract

The RewardDistributor is a smart contract project developed using Hardhat for managing the distribution of reward tokens in exchange for stablecoin deposits. It is designed for secure, upgradeable, and controlled token reward management, leveraging OpenZeppelin's battle-tested libraries.

## Project Overview

The core contract, `RewardDistributor.sol`, provides the following functionality:
- Deposits stablecoins (e.g., USDC) to mint reward tokens at a fixed rate (1000 reward tokens per USD).
- Supports off-chain signed reward claims using EIP-712 for secure and gas-efficient operations.
- Enables swapping reward tokens back for stablecoins.
- Allows admin-controlled budget withdrawals with signature verification.
- Provides administrative functions to update the admin address and minimum deposit amount.
- Incorporates security features such as pausability, role-based access control, and signature validation.

The contract is upgradeable via the UUPS proxy pattern and uses OpenZeppelin libraries for access control, pausability, and EIP-712 signature handling.

## Prerequisites

- Node.js (version 18 or later)
- Yarn or npm
- Hardhat (for development, testing, and deployment)

## Installation

1. Clone the repository:
   ```
   git clone <repository-url>
   cd reward-distributor
   ```

2. Install dependencies:
   ```
   npm install
   ```
   Alternatively, use `yarn install`.

3. Configure a `.env` file for deployment (optional for local testing, required for testnet/mainnet deployments with private keys).

## Usage

### Compiling Contracts

Compile the smart contracts using:
```
npx hardhat compile
```

### Running Tests

Comprehensive tests are provided in `test/RewardDistributor.ts`, covering contract initialization, role management, deposits, claims, swaps, withdrawals, and edge cases such as pausing and invalid signatures.

Run the tests with:
```
npx hardhat test
```

## Key Features

- **Deposits**: Users deposit stablecoins above a minimum threshold to mint reward tokens.
- **Claims**: Reward tokens are claimed via admin-signed EIP-712 messages, ensuring secure off-chain authorization.
- **Swaps**: Users can burn reward tokens to receive stablecoins.
- **Budget Withdrawals**: Admins can withdraw stablecoins with signed messages, burning corresponding reward tokens.
- **Admin Controls**: Functions to update the admin address and minimum deposit amount, restricted to authorized roles.
- **Security**: Role-based access control (admin, pauser, upgrader), pausability, and signature validation to prevent reuse or invalid operations.

## Mock Contracts

The project includes mock contracts (`RewardCoinMock` and `StableCoinMock`) for simulating ERC20 tokens during testing.

## Project Structure

- `contracts/RewardDistributor.sol`: Main contract implementing the reward distribution logic.
- `test/RewardDistributor.ts`: Hardhat test suite with full coverage of contract functionality.
- `contracts/interfaces/`: Interface definitions for the reward distributor and token contracts.
- `contracts/RewardDistributorStorage.sol`: Storage layout for the upgradeable contract.

## Contributing

Contributions are welcome. Please fork the repository, make changes, and submit a pull request with clear descriptions and accompanying tests.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.