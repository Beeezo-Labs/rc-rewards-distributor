// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IRCToken
 * @author Beeezo
 * @dev Interface for the RCToken contract, defining core functions for minting, burning,
 *      and managing authorized distributors.
 */
interface IRCToken {
    /**
     * @notice Error indicating that the caller is not authorized to perform the action.
     */
    error Unauthorized();

    /**
     * @notice Error indicating that a zero address was provided where a valid address is required.
     */
    error ZeroAddress();

    /**
     * @notice Error indicating that the distributor's configuration status is already set to the provided value.
     */
    error AlreadyConfigured();

    /**
     * @notice Emitted when a distributor is configured or updated.
     * @param distributor The address of the distributor being configured.
     * @param status The new status of the distributor (true if authorized, false if revoked).
     */
    event DistributorConfigured(address indexed distributor, bool status);

    /**
     * @notice Configures an address as an authorized distributor, allowing or revoking their ability to mint or burn tokens.
     * @param distributor The address of the distributor to configure.
     * @param status The status to set (true to authorize, false to revoke).
     * @dev Only callable by an admin account.
     * Reverts with `ZeroAddress` if the distributor address is zero.
     * Reverts with `AlreadyConfigured` if the distributor's status is already set to the given value.
     * Emits a {DistributorConfigured} event.
     */
    function configureDistributor(address distributor, bool status) external;

    /**
     * @notice Mints new tokens and assigns them to the caller.
     * @param amount The amount of tokens to mint.
     * @dev Only callable by an authorized distributor.
     */
    function mint(uint256 amount) external;

    /**
     * @notice Burns reward tokens from the caller's account.
     * @param amount The amount of reward tokens to burn.
     * @dev Only callable by an authorized distributor.
     */
    function burnRewardTokens(uint256 amount) external;

    /**
     * @notice Checks if a given account is an authorized distributor.
     * @param account The address of the account to check.
     * @return Boolean indicating whether the account is an authorized distributor.
     */
    function isDistributor(address account) external view returns (bool);
}
