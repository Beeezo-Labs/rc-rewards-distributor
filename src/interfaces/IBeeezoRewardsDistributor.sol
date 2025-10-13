// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IRewardDistributor
 * @author Beeezo
 * @dev Interface for the RewardDistributor contract, defining the core functions and events for managing
 *      the distribution of reward tokens in exchange for stablecoin deposits.
 */
interface IBeeezoRewardsDistributor {
    error InvalidAmount();
    error RoundAmountRequired();
    error ZeroAddress();
    event Deposit(address account, uint256 amountUSD, uint256 amountRC);
    event Cashback(address account, uint256 amountUSD, uint256 amountRC);
    event Swap(address account, uint256 amountUSD, uint256 amountRC);
    event RewardsDistributed(address account, uint256 amountRC, uint256 fee);
}