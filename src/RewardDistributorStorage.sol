// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title RewardDistributorStorage
 * @author Beeezo
 * @dev Storage contract for managing rewards distribution. This contract holds the essential variables
 *      related to deposits, rewards, and associated token and stablecoin addresses.
 */
contract RewardDistributorStorage {
    /// @notice Minimal deposit required to create reward coins
    uint256 internal _minimalDeposit;

    /// @notice The address of the stable coin contract
    address internal _stableCoin;

    /// @notice The address of the token being distributed as rewards
    address internal _rewardCoin;

    address internal _treasury;

    mapping(address => uint256) internal _totalDeposited;

    mapping(address => uint256) internal _totalWithdrawn;

    mapping(address => uint256) internal _totalEarned;

    /// @dev Reserved space to allow for future storage expansion without shifting down storage in derived contracts
    uint256[45] internal __gap;
}