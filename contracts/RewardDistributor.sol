// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRewardDistributor} from "./interfaces/IRewardDistributor.sol";
import {RewardDistributorStorage} from "./RewardDistributorStorage.sol";
import {IRCToken} from "./interfaces/IRCToken.sol";

/**
 * @title RewardDistributor
 * @author Yolllo
 * @dev Implements the distribution of reward tokens in exchange for stablecoin deposits. This contract
 *      supports features like deposits, claims, withdrawing budget, and upgrades, while ensuring security
 *      through role-based access control and signature validation using EIP-712.
 */
contract RewardDistributor is
    Initializable,
    PausableUpgradeable,
    EIP712Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    RewardDistributorStorage,
    IRewardDistributor
{
    using SafeERC20 for IERC20;

    /// @notice Role identifier for the Pauser role, which allows pausing and unpausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role identifier for the Upgrader role, which allows contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role identifier for the Admin role, which has higher-level administrative privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Fixed rate of reward tokens distributed per unit of stablecoin (USD)
    uint256 public constant REWARD_TOKENS_PER_USD = 1000;

    /// @notice Type hash for the budget withdrawal message in the EIP-712 standard
    bytes32 private constant _WITHDRAW_BUDGET_MESSAGE_TYPEHASH =
        keccak256(
            "WithdrawBudgetMessage(address admin,address sender,address receiver,address distributor,uint256 amount,address stableCoin,uint256 chainId,bytes32 salt)"
        );

    /// @notice Type hash for the claim message in the EIP-712 standard
    bytes32 private constant _CLAIM_MESSAGE_TYPEHASH =
        keccak256(
            "ClaimMessage(address admin,address sender,address distributor,uint256 amount,uint256 chainId,bytes32 salt,uint256 deadline)"
        );

    /**
     * @notice Constructor that disables initializers to prevent improper deployment.
     * @dev Ensures that the contract can only be initialized once by the upgradeable proxy mechanism.
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the reward distributor contract.
     * @param admin_ Address of the admin responsible for managing the contract.
     * @param pauser_ Address of the account allowed to pause and unpause the contract.
     * @param upgrader_ Address of the account allowed to upgrade the contract.
     * @param stableCoin_ Address of the stablecoin contract (used for deposits).
     * @param token_ Address of the reward token contract (used for distributing rewards).
     * @param minimalDeposit_ Minimum deposit amount required to participate.
     */
    function initialize(
        address admin_,
        address pauser_,
        address upgrader_,
        address stableCoin_,
        address token_,
        uint256 minimalDeposit_
    ) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __EIP712_init("RewardDistributor", "1.0.0");

        _stableCoin = stableCoin_;
        _token = token_;
        _admin = admin_;
        _minimalDeposit = minimalDeposit_;

        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, pauser_);
        _grantRole(UPGRADER_ROLE, upgrader_);
    }

    /**
     * @notice Pauses the contract, disabling the ability to deposit, claim, or swap.
     * @dev Only callable by an account with the PAUSER_ROLE.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract, re-enabling the ability to deposit, claim, or swap.
     * @dev Only callable by an account with the PAUSER_ROLE.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Deposits stablecoins into the contract, creating reward tokens.
     * @param amountInStableCoin Amount of stablecoins to deposit.
     * @dev The function transfers stablecoins from the sender and mints corresponding reward tokens. Reverts if the deposit amount is zero or below the minimal deposit requirement.
     * Emits a {Deposit} event.
     */
    function deposit(uint256 amountInStableCoin) external whenNotPaused {
        if (amountInStableCoin < _minimalDeposit) {
            revert InvalidAmount();
        }

        // Calculate the rewards based on the deposit amount
        uint256 rewards = calculateStableCoinToRewards(amountInStableCoin);

        // Transfer the stablecoins from the sender to the contract
        IERC20(_stableCoin).safeTransferFrom(msg.sender, address(this), amountInStableCoin);

        // Mint the corresponding amount of reward tokens
        IRCToken(_token).mint(rewards);

        emit Deposit(msg.sender, amountInStableCoin, rewards);
    }

    /**
     * @notice Allows withdrawing stablecoins and burning corresponding rewards.
     * @param receiver Address to receive the withdrawn stablecoins.
     * @param amountInStableCoin Amount of stablecoins to withdraw.
     * @param salt A unique salt value to ensure signature uniqueness.
     * @param signature EIP-712 signature from the admin to authorize the operation.
     * @dev The function checks if the signature has already been used, verifies the provided signature, and ensures the sender has sufficient funds invested. If the signature is valid, the stablecoins are withdrawn, and the reward tokens are burned. Emits a {WithdrawBudget} event.
     */
    function withdrawBudget(
        address receiver,
        uint256 amountInStableCoin,
        bytes32 salt,
        bytes memory signature
    ) external whenNotPaused {
        bytes32 signatureHash = keccak256(signature);
        if (_usedSignatures[signatureHash]) {
            revert SignatureReuse();
        }

        WithdrawBudgetMessage memory msgData = WithdrawBudgetMessage(
            _admin, // The admin address stored in the contract
            msg.sender, // The sender of this transaction
            receiver, // Receiver of the funds
            address(this), // The distributor (this contract)
            amountInStableCoin, // The amount involved in the withdrawal
            _stableCoin, // The stablecoin being used
            block.chainid, // Chain ID for the current network
            salt // The unique salt for this transaction
        );

        // Verify the signature using the constructed message
        if (!verifyWithdrawBudgetSignature(msgData, signature)) {
            revert InvalidSignature();
        }

        uint256 rewards = calculateStableCoinToRewards(amountInStableCoin);

        _usedSignatures[signatureHash] = true;

        IRCToken(_token).burnRewardTokens(rewards);
        IERC20(_stableCoin).safeTransfer(receiver, amountInStableCoin);

        emit WithdrawBudget(msg.sender, amountInStableCoin, rewards);
    }

    /**
     * @notice Withdraws stablecoins and burns corresponding reward tokens.
     * @param stableCoinAmount Amount of stablecoins to swap for reward coins.
     * @dev Transfers the stablecoins to the sender and burns the associated reward tokens. Emits a {Swap} event.
     */
    function swap(uint256 stableCoinAmount) external whenNotPaused {
        if (stableCoinAmount == 0) {
            revert ZeroAmount();
        }
        _swap(stableCoinAmount);
    }

    /**
     * @notice Claims reward tokens based on a valid signature.
     * @param rewards Amount of reward tokens to claim.
     * @param salt A unique salt value to ensure signature uniqueness.
     * @param signature EIP-712 signature from the admin to authorize the claim.
     * @dev Checks the validity of the claim signature and ensures it has not been reused. If valid, the rewards are transferred to the receiver. Emits a {Claim} event.
     */
    function claim(uint256 rewards, bytes32 salt, uint256 deadline, bytes memory signature) external whenNotPaused {
        if (rewards == 0) {
            revert ZeroAmount();
        }
        _claim(rewards, msg.sender, salt, deadline, signature);
    }

    /**
     * @notice Updates the admin of the contract.
     * @param newAdmin Address of the new admin.
     * @dev Only callable by the current admin. Reverts if the provided address is zero.
     * Emits a {NewAdmin} event.
     */
    function setAdmin(address newAdmin) external onlyRole(ADMIN_ROLE) {
        if (newAdmin == address(0)) {
            revert ZeroAddress();
        }

        _admin = newAdmin;
        emit NewAdmin(newAdmin);
    }

    /**
     * @notice Sets a new minimal deposit amount.
     * @param newAmount New minimal deposit amount.
     * @dev Only callable by the admin.
     * Emits a {NewMinimalDepositAmount} event.
     */
    function setNewMinimalDeposit(uint256 newAmount) external onlyRole(ADMIN_ROLE) {
        _minimalDeposit = newAmount;
        emit NewMinimalDepositAmount(newAmount);
    }

    /**
     * @notice Returns the address of the stablecoin used in the contract.
     * @return Address of the stablecoin.
     */
    function stableCoin() external view returns (address) {
        return _stableCoin;
    }

    /**
     * @notice Returns the address of the admin of the contract.
     * @return Address of the admin.
     */
    function admin() external view returns (address) {
        return _admin;
    }

    /**
     * @notice Returns the address of the reward token contract.
     * @return Address of the reward token.
     */
    function rewardCoin() external view returns (address) {
        return _token;
    }

    /**
     * @notice Returns the minimum deposit amount required to participate.
     * @return Minimal deposit amount.
     */
    function minimalDeposit() external view returns (uint256) {
        return _minimalDeposit;
    }

    /**
     * @notice Returns the total amount of stablecoins locked in the contract.
     * @return Total stablecoins locked.
     */
    function totalStableCoinsLocked() external view returns (uint256) {
        return IERC20(_stableCoin).balanceOf(address(this));
    }

    /**
     * @notice Returns the total amount of rewards available for distribution.
     * @return Total rewards available.
     */
    function totalRewardsAvailable() external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @notice Verifies the signature for claiming rewards.
     * @param message The ClaimMessage struct containing claim data.
     * @param signature EIP-712 signature from the admin authorizing the claim.
     * @return Boolean indicating whether the signature is valid.
     */
    function verifyClaimSignature(ClaimMessage memory message, bytes memory signature) public view returns (bool) {
        bytes32 structHash = keccak256(
            abi.encode(
                _CLAIM_MESSAGE_TYPEHASH,
                message.admin,
                message.sender,
                message.distributor,
                message.amount,
                message.chainId,
                message.salt,
                message.deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);

        address recoveredSigner = ECDSA.recover(digest, signature);
        return recoveredSigner == _admin;
    }

    /**
     * @notice Verifies the signature for withdrawing the budget.
     * @param message The WithdrawBudgetMessage struct containing withdrawal data.
     * @param signature EIP-712 signature from the admin authorizing the withdrawal.
     * @return Boolean indicating whether the signature is valid.
     */
    function verifyWithdrawBudgetSignature(
        WithdrawBudgetMessage memory message,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 structHash = keccak256(
            abi.encode(
                _WITHDRAW_BUDGET_MESSAGE_TYPEHASH,
                message.admin,
                message.sender,
                message.receiver,
                message.distributor,
                message.amount,
                message.stableCoin,
                message.chainId,
                message.salt
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);

        address recoveredSigner = ECDSA.recover(digest, signature);
        return recoveredSigner == _admin;
    }

    function calculateStableCoinToRewards(uint256 amountInStableCoin) public view returns (uint256) {
        return (amountInStableCoin * REWARD_TOKENS_PER_USD) / (10 ** IERC20Metadata(_stableCoin).decimals());
    }

    /**
     * @notice Claims reward tokens internally after verifying the signature.
     * @param rewards Amount of reward tokens to claim.
     * @param receiver Address receiving the reward tokens.
     * @param salt Unique salt for ensuring the signature's uniqueness.
     * @param deadline The last timestamp that will allow to use the signature.
     * @param signature EIP-712 signature from the admin.
     * @dev Emits a {Claim} event.
     */
    function _claim(
        uint256 rewards,
        address receiver,
        bytes32 salt,
        uint256 deadline,
        bytes memory signature
    ) internal {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }
        if (_usedSignatures[keccak256(signature)]) {
            revert SignatureReuse();
        }

        ClaimMessage memory msgData = ClaimMessage(
            _admin, // The admin address
            receiver, // The sender
            address(this), // Distributor (this contract)
            rewards, // Rewards amount
            block.chainid, // Chain ID
            salt, // Unique salt for this message
            deadline // Deadline for this signature
        );

        if (!verifyClaimSignature(msgData, signature)) {
            revert InvalidSignature();
        }

        _usedSignatures[keccak256(signature)] = true;

        IERC20(_token).safeTransfer(receiver, rewards);

        emit Claim(msg.sender, receiver, rewards, salt);
    }

    /**
     * @notice Internal function to handle reward coins swap and burn in exchange for stablecoins.
     * @param stableCoinAmount Amount of stablecoins to swap.
     * @dev Emits a {Swap} event.
     */
    function _swap(uint256 stableCoinAmount) internal {
        // Calculate the equivalent reward tokens to burn (1 stablecoin unit = 1000 reward tokens)
        uint256 rewardAmount = calculateStableCoinToRewards(stableCoinAmount);

        // Burn the equivalent reward tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), rewardAmount);
        IRCToken(_token).burnRewardTokens(rewardAmount);

        // Transfer stablecoins to the user
        IERC20(_stableCoin).safeTransfer(msg.sender, stableCoinAmount);

        emit Swap(msg.sender, stableCoinAmount, rewardAmount);
    }

    /**
     * @notice Authorizes upgrades to the contract.
     * @param newImplementation Address of the new contract implementation.
     * @dev Only callable by an account with the UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
