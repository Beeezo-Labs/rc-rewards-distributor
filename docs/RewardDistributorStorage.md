# Solidity API

## RewardDistributorStorage

_Storage contract for managing rewards distribution. This contract holds the essential variables
     related to deposits, rewards, and associated token and stablecoin addresses._

### _minimalDeposit

```solidity
uint256 _minimalDeposit
```

Minimal deposit required to participate

### _stableCoin

```solidity
address _stableCoin
```

The address of the stable coin contract

### _admin

```solidity
address _admin
```

The address of the admin with specific access rights

### _token

```solidity
address _token
```

The address of the token being distributed as rewards

### _usedSignatures

```solidity
mapping(bytes32 => bool) _usedSignatures
```

Tracks whether a given signature has been used to prevent double usage

_Maps a signature hash to a boolean indicating if it has been used_

### __gap

```solidity
uint256[45] __gap
```

_Reserved space to allow for future storage expansion without shifting down storage in derived contracts_

