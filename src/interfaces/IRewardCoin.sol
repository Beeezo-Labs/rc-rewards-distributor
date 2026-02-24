// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IRewardCoin
/// @author Beeezo
/// @notice Interface for the RewardCoin token, exposing the mint and burn operations
///         required by the distributor contract.
interface IRewardCoin {
    /// @notice Mints `amount` reward tokens to the caller.
    /// @dev Implementors must restrict access to authorised callers (e.g. the distributor).
    /// @param amount The number of tokens to mint (in the token's own decimals).
    function mint(uint256 amount) external;

    /// @notice Burns `amount` reward tokens from the caller's balance.
    /// @dev Used by the distributor when processing cashbacks and swaps.
    /// @param amount The number of tokens to burn (in the token's own decimals).
    function burnRewardTokens(uint256 amount) external;
}