# Solidity API

## RewardDistributor

_Implements the distribution of reward tokens in exchange for stablecoin deposits. This contract
     supports features like deposits, claims, withdrawing budget, and upgrades, while ensuring security
     through role-based access control and signature validation using EIP-712._

### PAUSER_ROLE

```solidity
bytes32 PAUSER_ROLE
```

Role identifier for the Pauser role, which allows pausing and unpausing the contract

### UPGRADER_ROLE

```solidity
bytes32 UPGRADER_ROLE
```

Role identifier for the Upgrader role, which allows contract upgrades

### ADMIN_ROLE

```solidity
bytes32 ADMIN_ROLE
```

Role identifier for the Admin role, which has higher-level administrative privileges

### REWARD_TOKENS_PER_USD

```solidity
uint256 REWARD_TOKENS_PER_USD
```

Fixed rate of reward tokens distributed per unit of stablecoin (USD)

### constructor

```solidity
constructor() public
```

Constructor that disables initializers to prevent improper deployment.

_Ensures that the contract can only be initialized once by the upgradeable proxy mechanism._

### initialize

```solidity
function initialize(address admin_, address pauser_, address upgrader_, address stableCoin_, address token_, uint256 minimalDeposit_) public
```

Initializes the reward distributor contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| admin_ | address | Address of the admin responsible for managing the contract. |
| pauser_ | address | Address of the account allowed to pause and unpause the contract. |
| upgrader_ | address | Address of the account allowed to upgrade the contract. |
| stableCoin_ | address | Address of the stablecoin contract (used for deposits). |
| token_ | address | Address of the reward token contract (used for distributing rewards). |
| minimalDeposit_ | uint256 | Minimum deposit amount required to participate. |

### pause

```solidity
function pause() external
```

Pauses the contract, disabling the ability to deposit, claim, or swap.

_Only callable by an account with the PAUSER_ROLE._

### unpause

```solidity
function unpause() external
```

Unpauses the contract, re-enabling the ability to deposit, claim, or swap.

_Only callable by an account with the PAUSER_ROLE._

### deposit

```solidity
function deposit(uint256 amountInStableCoin) external
```

Deposits stablecoins into the contract, creating reward tokens.

_The function transfers stablecoins from the sender and mints corresponding reward tokens. Reverts if the deposit amount is zero or below the minimal deposit requirement.
Emits a {Deposit} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountInStableCoin | uint256 | Amount of stablecoins to deposit. |

### withdrawBudget

```solidity
function withdrawBudget(address receiver, uint256 amountInStableCoin, bytes32 salt, bytes signature) external
```

Allows withdrawing stablecoins and burning corresponding rewards.

_The function checks if the signature has already been used, verifies the provided signature, and ensures the sender has sufficient funds invested. If the signature is valid, the stablecoins are withdrawn, and the reward tokens are burned. Emits a {WithdrawBudget} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | Address to receive the withdrawn stablecoins. |
| amountInStableCoin | uint256 | Amount of stablecoins to withdraw. |
| salt | bytes32 | A unique salt value to ensure signature uniqueness. |
| signature | bytes | EIP-712 signature from the admin to authorize the operation. |

### swap

```solidity
function swap(uint256 stableCoinAmount) external
```

Withdraws stablecoins and burns corresponding reward tokens.

_Transfers the stablecoins to the sender and burns the associated reward tokens. Emits a {Swap} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| stableCoinAmount | uint256 | Amount of stablecoins to swap for reward coins. |

### claim

```solidity
function claim(uint256 rewards, bytes32 salt, uint256 deadline, bytes signature) external
```

Claims reward tokens based on a valid signature.

_Checks the validity of the claim signature and ensures it has not been reused. If valid, the rewards are transferred to the receiver. Emits a {Claim} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewards | uint256 | Amount of reward tokens to claim. |
| salt | bytes32 | A unique salt value to ensure signature uniqueness. |
| deadline | uint256 |  |
| signature | bytes | EIP-712 signature from the admin to authorize the claim. |

### setAdmin

```solidity
function setAdmin(address newAdmin) external
```

Updates the admin of the contract.

_Only callable by the current admin. Reverts if the provided address is zero.
Emits a {NewAdmin} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newAdmin | address | Address of the new admin. |

### setNewMinimalDeposit

```solidity
function setNewMinimalDeposit(uint256 newAmount) external
```

Sets a new minimal deposit amount.

_Only callable by the admin.
Emits a {NewMinimalDepositAmount} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newAmount | uint256 | New minimal deposit amount. |

### stableCoin

```solidity
function stableCoin() external view returns (address)
```

Returns the address of the stablecoin used in the contract.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | Address of the stablecoin. |

### admin

```solidity
function admin() external view returns (address)
```

Returns the address of the admin of the contract.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | Address of the admin. |

### rewardCoin

```solidity
function rewardCoin() external view returns (address)
```

Returns the address of the reward token contract.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | Address of the reward token. |

### minimalDeposit

```solidity
function minimalDeposit() external view returns (uint256)
```

Returns the minimum deposit amount required to participate.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Minimal deposit amount. |

### totalStableCoinsLocked

```solidity
function totalStableCoinsLocked() external view returns (uint256)
```

Returns the total amount of stablecoins locked in the contract.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Total stablecoins locked. |

### totalRewardsAvailable

```solidity
function totalRewardsAvailable() external view returns (uint256)
```

Returns the total amount of rewards available for distribution.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Total rewards available. |

### verifyClaimSignature

```solidity
function verifyClaimSignature(struct IRewardDistributorTypes.ClaimMessage message, bytes signature) public view returns (bool)
```

Verifies the signature for claiming rewards.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct IRewardDistributorTypes.ClaimMessage | The ClaimMessage struct containing claim data. |
| signature | bytes | EIP-712 signature from the admin authorizing the claim. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | Boolean indicating whether the signature is valid. |

### verifyWithdrawBudgetSignature

```solidity
function verifyWithdrawBudgetSignature(struct IRewardDistributorTypes.WithdrawBudgetMessage message, bytes signature) public view returns (bool)
```

Verifies the signature for withdrawing the budget.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct IRewardDistributorTypes.WithdrawBudgetMessage | The WithdrawBudgetMessage struct containing withdrawal data. |
| signature | bytes | EIP-712 signature from the admin authorizing the withdrawal. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | Boolean indicating whether the signature is valid. |

### calculateStableCoinToRewards

```solidity
function calculateStableCoinToRewards(uint256 amountInStableCoin) public view returns (uint256)
```

### _claim

```solidity
function _claim(uint256 rewards, address receiver, bytes32 salt, uint256 deadline, bytes signature) internal
```

Claims reward tokens internally after verifying the signature.

_Emits a {Claim} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewards | uint256 | Amount of reward tokens to claim. |
| receiver | address | Address receiving the reward tokens. |
| salt | bytes32 | Unique salt for ensuring the signature's uniqueness. |
| deadline | uint256 | The last timestamp that will allow to use the signature. |
| signature | bytes | EIP-712 signature from the admin. |

### _swap

```solidity
function _swap(uint256 stableCoinAmount) internal
```

Internal function to handle reward coins swap and burn in exchange for stablecoins.

_Emits a {Swap} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| stableCoinAmount | uint256 | Amount of stablecoins to swap. |

### _authorizeUpgrade

```solidity
function _authorizeUpgrade(address newImplementation) internal
```

Authorizes upgrades to the contract.

_Only callable by an account with the UPGRADER_ROLE._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newImplementation | address | Address of the new contract implementation. |

