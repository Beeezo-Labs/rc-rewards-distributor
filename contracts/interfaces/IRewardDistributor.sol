// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IRewardDistributorTypes
 * @author Yolllo
 * @dev Contains common data structures used by the RewardDistributor contract, including messages
 *      for withdrawing budget and claiming rewards.
 */
interface IRewardDistributorTypes {
    /**
     * @notice Structure used for withdrawing budget.
     * @param admin The address of the admin.
     * @param sender The address of the transaction sender.
     * @param receiver The address of the stablecoin receiver.
     * @param distributor The address of the reward distributor (contract itself).
     * @param amount The amount of stablecoins involved in the transaction.
     * @param stableCoin The address of the stablecoin.
     * @param chainId The chain ID of the current blockchain.
     * @param salt A unique salt to ensure signature uniqueness.
     */
    struct WithdrawBudgetMessage {
        address admin;
        address sender;
        address receiver;
        address distributor;
        uint256 amount;
        address stableCoin;
        uint256 chainId;
        bytes32 salt;
    }

    /**
     * @notice Structure used for claiming rewards.
     * @param admin The address of the admin.
     * @param sender The address of the transaction sender.
     * @param distributor The address of the reward distributor (contract itself).
     * @param amount The amount of rewards to claim.
     * @param chainId The chain ID of the current blockchain.
     * @param salt A unique salt to ensure signature uniqueness.
     */
    struct ClaimMessage {
        address admin;
        address sender;
        address distributor;
        uint256 amount;
        uint256 chainId;
        bytes32 salt;
        uint256 deadline;
    }
}

/**
 * @title IRewardDistributor
 * @author Yolllo
 * @dev Interface for the RewardDistributor contract, defining the core functions and events for managing
 *      the distribution of reward tokens in exchange for stablecoin deposits.
 */
interface IRewardDistributor is IRewardDistributorTypes {
    /**
     * @notice Error for when the signature chain ID is invalid.
     */
    error InvalidSignatureChainId();

    /**
     * @notice Error for when a zero amount is provided in a function.
     */
    error ZeroAmount();

    /**
     * @notice Error for when an invalid signature is provided.
     */
    error InvalidSignature();

    /**
     * @notice Error for when a signature is reused.
     */
    error SignatureReuse();

    /**
     * @notice Error for when a zero address is provided as an argument.
     */
    error ZeroAddress();

    /**
     * @notice Error for when an invalid amount is provided (e.g., less than the minimal deposit).
     */
    error InvalidAmount();

    /**
     * @notice Error for when the signature's specific deadline already passed.
     */
    error SignatureExpired();

    /**
     * @notice Emitted when a participant deposits stablecoins and receives reward tokens.
     * @param owner The address of the participant who made the deposit.
     * @param usdAmount The amount of stablecoins deposited.
     * @param rewards The amount of reward tokens minted as a result.
     */
    event Deposit(address indexed owner, uint256 usdAmount, uint256 rewards);

    /**
     * @notice Emitted when a budget is withdrawn by the investor.
     * @param poolOwner The address of the participant who owned the pool.
     * @param usdAmount The amount of stablecoins withdrawn.
     * @param rewards The amount of reward tokens burned as a result.
     */
    event WithdrawBudget(address indexed poolOwner, uint256 usdAmount, uint256 rewards);

    /**
     * @notice Emitted when a participant withdraws stablecoins and burns the corresponding reward tokens.
     * @param user The address of the participant making the withdrawal.
     * @param usdAmount The amount of stablecoins withdrawn.
     * @param rewards The amount of reward tokens burned as a result.
     */
    event Swap(address indexed user, uint256 usdAmount, uint256 rewards);

    /**
     * @notice Emitted when a participant claims reward tokens.
     * @param caller The address of the participant making the claim.
     * @param receiver The address receiving the reward tokens.
     * @param rewards The amount of reward tokens claimed.
     * @param salt The unique salt identifier of the claim.
     */
    event Claim(address indexed caller, address indexed receiver, uint256 rewards, bytes32 salt);

    /**
     * @notice Emitted when the admin of the contract is changed.
     * @param admin The new admin address.
     */
    event NewAdmin(address indexed admin);

    /**
     * @notice Emitted when the minimum deposit amount is updated.
     * @param amount The new minimum deposit amount.
     */
    event NewMinimalDepositAmount(uint256 amount);

    /**
     * @notice Deposits stablecoins into the contract and mints reward tokens.
     * @param amount The amount of stablecoins to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraws the amount of stablecoins to refund the investor.
     * @param receiver The address receiving the withdrawn stablecoins.
     * @param amount The amount of stablecoins to withdraw.
     * @param salt A unique salt to ensure signature uniqueness.
     * @param signature The EIP-712 signature authorizing the budget withdrawal.
     */
    function withdrawBudget(address receiver, uint256 amount, bytes32 salt, bytes memory signature) external;

    /**
     * @notice Withdraws stablecoins from the contract and burns the corresponding reward tokens.
     * @param amountUSD The amount of stablecoins to withdraw.
     */
    function swap(uint256 amountUSD) external;

    /**
     * @notice Claims reward tokens by providing a valid signature.
     * @param rewards The amount of reward tokens to claim.
     * @param salt A unique salt to ensure signature uniqueness.
     * @param signature The EIP-712 signature authorizing the claim.
     */
    function claim(uint256 rewards, bytes32 salt, uint256 deadline, bytes memory signature) external;

    /**
     * @notice Sets a new admin for the contract.
     * @param newAdmin The address of the new admin.
     */
    function setAdmin(address newAdmin) external;

    /**
     * @notice Sets a new minimum deposit amount.
     * @param newAmount The new minimum deposit amount.
     */
    function setNewMinimalDeposit(uint256 newAmount) external;

    /**
     * @notice Returns the address of the stablecoin contract.
     * @return The stablecoin contract address.
     */
    function stableCoin() external view returns (address);

    /**
     * @notice Returns the address of the admin.
     * @return The admin address.
     */
    function admin() external view returns (address);

    /**
     * @notice Returns the address of the reward token contract.
     * @return The reward token contract address.
     */
    function rewardCoin() external view returns (address);

    /**
     * @notice Returns the minimum deposit amount required to participate.
     * @return The minimum deposit amount.
     */
    function minimalDeposit() external view returns (uint256);

    /**
     * @notice Returns the total amount of stablecoins locked in the contract.
     * @return The total stablecoins locked.
     */
    function totalStableCoinsLocked() external view returns (uint256);

    /**
     * @notice Returns the total amount of rewards available for distribution.
     * @return The total rewards available.
     */
    function totalRewardsAvailable() external view returns (uint256);

    /**
     * @notice Verifies the signature for a claim message.
     * @param message The ClaimMessage containing claim details.
     * @param signature The EIP-712 signature to verify.
     * @return A boolean indicating whether the signature is valid.
     */
    function verifyClaimSignature(ClaimMessage memory message, bytes memory signature) external view returns (bool);

    /**
     * @notice Verifies the signature for a budget withdrawal message.
     * @param message The WithdrawBudgetMessage containing refunding details.
     * @param signature The EIP-712 signature to verify.
     * @return A boolean indicating whether the signature is valid.
     */
    function verifyWithdrawBudgetSignature(
        WithdrawBudgetMessage memory message,
        bytes memory signature
    ) external view returns (bool);
}
