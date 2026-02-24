// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title RewardDistributorStorage
/// @author Beeezo
/// @notice Isolated storage layout for BeeezoRewardsDistributor.
/// @dev This contract is inherited by BeeezoRewardsDistributor and must never be used
///      standalone. All variables are declared here to keep the storage layout stable
///      across UUPS upgrades. The `__gap` array reserves space for future additions
///      without shifting inherited storage slots.
contract RewardDistributorStorage {
    /// @notice Minimum stablecoin amount (in raw token units) required for a deposit.
    uint256 internal _minimalDeposit;

    /// @notice Address of the accepted stablecoin (e.g. USDC).
    address internal _stableCoin;

    /// @notice Address of the reward token (RC) contract.
    address internal _rewardCoin;

    /// @notice Address of the treasury that receives distribution fees.
    address internal _treasury;

    /// @notice Cumulative stablecoin amount deposited by each address (raw token units).
    mapping(address => uint256) internal _totalDeposited;

    /// @notice Cumulative stablecoin amount returned via cashback to each address (raw token units).
    mapping(address => uint256) internal _totalWithdrawn;

    /// @notice Cumulative reward tokens distributed to each address (RC units).
    mapping(address => uint256) internal _totalEarned;

    /// @dev Reserved storage gap so that future variables can be added to this contract
    ///      without colliding with storage slots in derived contracts.
    ///      Current usage: 5 slots. Target: 50 slots total (5 used + 45 reserved).
    uint256[45] internal __gap;
}