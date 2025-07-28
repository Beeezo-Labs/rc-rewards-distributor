// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title RewardDistributorStorage
 * @author Yolllo
 * @dev Storage contract for managing rewards distribution. This contract holds the essential variables
 *      related to deposits, rewards, and associated token and stablecoin addresses.
 */
contract RewardDistributorStorage {
    /// @notice Minimal deposit required to participate
    uint256 internal _minimalDeposit;

    /// @notice The address of the stable coin contract
    address internal _stableCoin;

    /// @notice The address of the admin with specific access rights
    address internal _admin;

    /// @notice The address of the token being distributed as rewards
    address internal _token;

    /// @notice Tracks whether a given signature has been used to prevent double usage
    /// @dev Maps a signature hash to a boolean indicating if it has been used
    mapping(bytes32 => bool) internal _usedSignatures;

    /// @dev Reserved space to allow for future storage expansion without shifting down storage in derived contracts
    uint256[45] internal __gap;
}
