// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IBeeezoRewardsDistributor
/// @author Beeezo
/// @notice Interface for the BeeezoRewardsDistributor contract, defining the errors and
///         events emitted during deposits, cashbacks, swaps, and reward distributions.
interface IBeeezoRewardsDistributor {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when a provided amount is zero, below the required minimum,
    ///         or exceeds the caller's available balance.
    error InvalidAmount();

    /// @notice Thrown when a stablecoin amount is not an exact whole-unit value
    ///         (i.e. not a multiple of the stablecoin's denomination).
    error RoundAmountRequired();

    /// @notice Thrown when a required address argument is the zero address.
    error ZeroAddress();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a user deposits stablecoins and reward tokens are minted.
    /// @param account  The address that made the deposit.
    /// @param amountUSD The deposited amount expressed in whole USD units.
    /// @param amountRC  The number of reward tokens minted as a result of the deposit.
    event Deposit(address indexed account, uint256 amountUSD, uint256 amountRC);

    /// @notice Emitted when an admin returns stablecoins to a depositor (cashback).
    /// @param account   The address receiving the cashback.
    /// @param amountUSD The cashback amount expressed in whole USD units.
    /// @param amountRC  The number of reward tokens burned as part of the cashback.
    event Cashback(address indexed account, uint256 amountUSD, uint256 amountRC);

    /// @notice Emitted when a user swaps reward tokens for stablecoins.
    /// @param account   The address that performed the swap.
    /// @param amountUSD The stablecoin amount (raw, including decimals) sent to the user.
    /// @param amountRC  The number of reward tokens burned in the swap.
    event Swap(address indexed account, uint256 amountUSD, uint256 amountRC);

    /// @notice Emitted when the distributor role sends earned reward tokens to a user.
    /// @param account  The address receiving the reward tokens.
    /// @param amountRC The gross reward amount (including fee) distributed.
    /// @param fee      The portion of `amountRC` redirected to the treasury.
    event RewardsDistributed(address indexed account, uint256 amountRC, uint256 fee);

    /// @notice Emitted when the accepted stablecoin address is updated.
    /// @param newStableCoin New stablecoin contract address.
    event StableCoinSet(address indexed newStableCoin);

    /// @notice Emitted when the reward token address is updated.
    /// @param newRewardCoin New reward token contract address.
    event RewardCoinSet(address indexed newRewardCoin);

    /// @notice Emitted when the minimum deposit amount is updated.
    /// @param newMinimalDeposit New minimum deposit in raw stablecoin units.
    event MinimalDepositSet(uint256 newMinimalDeposit);

    /// @notice Emitted when the treasury address is updated.
    /// @param newTreasury New treasury address.
    event TreasurySet(address indexed newTreasury);
}