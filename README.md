# BeeezoRewardsDistributor

UUPS-upgradeable reward distribution contract. Users deposit stablecoins (USDC) and receive RC reward tokens. An off-chain distributor service pushes earned rewards to user wallets, and users can swap RC back to USDC at a fixed rate.

## How it works

```
User                    Contract                 RC Token
 |                          |                       |
 |-- deposit(amount) ------>|                       |
 |   (USDC transferred in)  |-- mint(amountRC) ---->|
 |                          |   (RC held by contract)
 |                          |                       |
 |<-- distributeRewards() --|   (off-chain trigger) |
 |   (RC transferred out)   |                       |
 |                          |                       |
 |-- swapRC(amount) ------->|                       |
 |   (RC transferred in)    |-- burn(amount) ------>|
 |<-- (USDC transferred out)|                       |
```

**Exchange rates:**
- Deposit: 1 USDC → 1,000 RC
- Swap: 1,000 RC → 1 USDC

## Contracts

```
src/
├── BeeezoRewardsDistributor.sol   — main proxy-compatible contract
├── RewardDistributorStorage.sol   — isolated storage layout (UUPS safe)
├── interfaces/
│   ├── IBeeezoRewardsDistributor.sol
│   └── IRewardCoin.sol
└── mock/
    ├── RewardCoinMock.sol          — 0-decimal RC token for local testing
    └── StableCoinMock.sol          — 6-decimal USDC mock for local testing
```

### Roles

| Role | Capability |
|---|---|
| `DEFAULT_ADMIN_ROLE` | Configuration, cashback, role management |
| `PAUSER_ROLE` | Emergency pause / unpause |
| `UPGRADER_ROLE` | Authorise UUPS implementation upgrades |
| `DISTRIBUTOR_ROLE` | Push earned RC rewards to user addresses |

## Setup

**Prerequisites:** [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
git clone <repo>
cd rc-rewards-distributor
forge install
```

Copy and fill in the environment file:

```bash
cp .env.example .env
```

## Build & Test

```bash
forge build
forge test
forge fmt          # format
forge snapshot     # gas snapshots
```

## Deploy

Set the required variables in `.env` (see `.env.example`):

| Variable | Description |
|---|---|
| `PRIVATE_KEY` | Deployer private key (must be funded) |
| `DEFAULT_ADMIN_ADDRESS` | Granted `DEFAULT_ADMIN_ROLE`, used as initial treasury |
| `PAUSER_ADDRESS` | Granted `PAUSER_ROLE` |
| `UPGRADER_ADDRESS` | Granted `UPGRADER_ROLE` |
| `DISTRIBUTOR_ADDRESS` | Granted `DISTRIBUTOR_ROLE` |
| `STABLE_COIN_ADDRESS` | Accepted stablecoin address (e.g. USDC) |
| `REWARD_COIN_ADDRESS` | RC reward token address |
| `MINIMAL_DEPOSIT` | Minimum deposit in raw stablecoin units (e.g. `1000000` = 1 USDC) |

```bash
forge script script/DeployDistributor.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

The script deploys the implementation and proxy in a single transaction batch, then logs both addresses.

## Upgrade

Set the additional variable in `.env`:

| Variable | Description |
|---|---|
| `PROXY_ADDRESS` | Address of the existing `BeeezoRewardsDistributor` proxy |

The signer identified by `PRIVATE_KEY` must hold `UPGRADER_ROLE` on the proxy.

```bash
forge script script/UpgradeDistributor.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

The script deploys a new implementation and calls `upgradeToAndCall` on the proxy.

## Local dev with Anvil

```bash
anvil
```

Use the default Anvil mnemonic (`test test test ... junk`) and deploy the mocks alongside the distributor by pointing `STABLE_COIN_ADDRESS` / `REWARD_COIN_ADDRESS` at freshly-deployed `StableCoinMock` / `RewardCoinMock` instances, or wire the deploy script to deploy mocks as part of the run.
