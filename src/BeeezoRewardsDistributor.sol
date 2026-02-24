// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IBeeezoRewardsDistributor} from "./interfaces/IBeeezoRewardsDistributor.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRewardCoin} from "./interfaces/IRewardCoin.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RewardDistributorStorage} from "./RewardDistributorStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title BeeezoRewardsDistributor
/// @author Beeezo
/// @notice Accepts stablecoin deposits, mints reward tokens (RC) to represent loyalty
///         points, and lets users swap RC back for stablecoins. An off-chain distributor
///         role pushes earned rewards to user wallets directly.
/// @dev UUPS-upgradeable proxy contract. Storage layout is defined in
///      RewardDistributorStorage. Role hierarchy:
///      - DEFAULT_ADMIN_ROLE  — configuration, cashback, role management
///      - PAUSER_ROLE         — emergency pause / unpause
///      - UPGRADER_ROLE       — authorises UUPS implementation upgrades
///      - DISTRIBUTOR_ROLE    — pushes earned RC rewards to users
///
///      Deposit flow:
///        1. User calls `deposit(amount)` with stablecoin pre-approved.
///        2. Stablecoin is pulled into this contract.
///        3. RC is minted to this contract at `REWARD_TOKENS_PER_USD` rate.
///        4. Off-chain service later calls `distributeRewards` to send RC to users.
contract BeeezoRewardsDistributor is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, RewardDistributorStorage, IBeeezoRewardsDistributor {
    using SafeERC20 for IERC20;

    /// @dev Intermediate result of converting a raw stablecoin amount.
    struct ConvertedFunds {
        /// @dev Whole-unit USD value (stablecoin amount divided by its denomination).
        uint256 amountUSD;
        /// @dev Equivalent RC token amount at the fixed exchange rate.
        uint256 amountRC;
    }

    /// @notice Number of RC tokens minted per whole USD deposited.
    /// @dev e.g. depositing 1 USDC (1_000_000 raw) yields 1_000 RC.
    uint256 public constant REWARD_TOKENS_PER_USD = 1000;

    /// @notice Raw stablecoin units returned per RC token on a swap.
    /// @dev RC has 0 decimals. USDC has 6 decimals.
    ///      1 RC → 1_000 raw USDC → 0.001 USDC.
    ///      1_000 RC → 1_000_000 raw USDC → 1 USDC.
    uint256 public constant RAW_USDC_PER_REWARD_TOKEN = 1000;

    /// @notice Minimum number of RC tokens that can be distributed in a single call.
    uint256 public constant MINIMUM_DISTRIBUTE_AMOUNT = 100;

    /// @notice Role that can pause and unpause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role that can authorise UUPS implementation upgrades.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role that can push earned RC rewards to user addresses.
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialises the proxy with roles, token addresses, and deposit constraints.
    /// @dev Can only be called once (enforced by `initializer`).
    ///      `_treasury` is set to `defaultAdmin` and can be updated via `setTreasury`.
    /// @param defaultAdmin    Address granted DEFAULT_ADMIN_ROLE and used as initial treasury.
    /// @param pauser          Address granted PAUSER_ROLE.
    /// @param upgrader        Address granted UPGRADER_ROLE.
    /// @param distributor     Address granted DISTRIBUTOR_ROLE.
    /// @param stableCoin_     Address of the accepted stablecoin (e.g. USDC).
    /// @param rewardCoin_     Address of the RC reward token contract.
    /// @param minimalDeposit_ Minimum raw stablecoin amount accepted by `deposit`.
    function initialize(
        address defaultAdmin,
        address pauser,
        address upgrader,
        address distributor,
        address stableCoin_,
        address rewardCoin_,
        uint256 minimalDeposit_
    ) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(DISTRIBUTOR_ROLE, distributor);

        _stableCoin = stableCoin_;
        _rewardCoin = rewardCoin_;
        _minimalDeposit = minimalDeposit_;
        _treasury = defaultAdmin;
    }

    // -------------------------------------------------------------------------
    // Pause
    // -------------------------------------------------------------------------

    /// @notice Pauses all user-facing state-changing operations.
    /// @dev Caller must hold PAUSER_ROLE.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes all user-facing state-changing operations.
    /// @dev Caller must hold PAUSER_ROLE.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // -------------------------------------------------------------------------
    // Core operations
    // -------------------------------------------------------------------------

    /// @notice Deposits stablecoins and triggers minting of the equivalent RC tokens.
    /// @dev Stablecoin amount must be an exact whole-unit value (no fractional USD).
    ///      RC is minted to this contract and later distributed via `distributeRewards`.
    ///      Emits {Deposit}.
    /// @param amount Raw stablecoin amount to deposit (must be ≥ `_minimalDeposit`).
    function deposit(uint256 amount) external whenNotPaused {
        if (amount < _minimalDeposit) {
            revert InvalidAmount();
        }

        ConvertedFunds memory funds = convertStableCoins(amount);
        _totalDeposited[msg.sender] += amount;

        IERC20(_stableCoin).safeTransferFrom(msg.sender, address(this), amount);
        IRewardCoin(_rewardCoin).mint(funds.amountRC);

        emit Deposit(msg.sender, funds.amountUSD, funds.amountRC);
    }

    /// @notice Returns stablecoins to a depositor and burns the corresponding RC tokens.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE. `amount` must not exceed the receiver's
    ///      net deposited balance (`_totalDeposited - _totalWithdrawn`).
    ///      The contract must hold enough RC to cover the burn.
    ///      Emits {Cashback}.
    /// @param receiver Address to receive the stablecoin refund.
    /// @param amount   Raw stablecoin amount to return (must be an exact whole-unit value).
    function cashback(address receiver, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (receiver == address(0)) {
            revert ZeroAddress();
        }

        uint256 currentFunds = _totalDeposited[receiver] - _totalWithdrawn[receiver];
        if (amount > currentFunds) {
            revert InvalidAmount();
        }

        ConvertedFunds memory funds = convertStableCoins(amount);
        _totalWithdrawn[receiver] += amount;

        IRewardCoin(_rewardCoin).burnRewardTokens(funds.amountRC);
        IERC20(_stableCoin).safeTransfer(receiver, amount);
        emit Cashback(receiver, funds.amountUSD, funds.amountRC);
    }

    /// @notice Swaps RC tokens held by the caller for stablecoins at the fixed rate.
    /// @dev RC tokens are pulled from the caller, then burned. The caller receives
    ///      `amount * RAW_USDC_PER_REWARD_TOKEN` raw stablecoin units.
    ///      The contract must hold sufficient stablecoin liquidity.
    ///      Emits {Swap}.
    /// @param amount Number of RC tokens to swap (RC has 0 decimals).
    function swapRC(uint256 amount) external whenNotPaused {
        if (amount == 0) {
            revert InvalidAmount();
        }

        IERC20(_rewardCoin).safeTransferFrom(msg.sender, address(this), amount);
        IRewardCoin(_rewardCoin).burnRewardTokens(amount);

        uint256 amountUSDC = (amount * RAW_USDC_PER_REWARD_TOKEN);

        IERC20(_stableCoin).safeTransfer(msg.sender, amountUSDC);

        emit Swap(msg.sender, amountUSDC, amount);
    }

    /// @notice Transfers earned RC tokens to a user, deducting a treasury fee.
    /// @dev Caller must hold DISTRIBUTOR_ROLE. Reverts with {InvalidAmount} if `fee > amount`.
    ///      The net amount sent to `receiver` is `amount - fee`; `fee` goes to `_treasury`.
    ///      Emits {RewardsDistributed}.
    /// @param receiver Address to receive the net reward tokens.
    /// @param amount   Gross RC token amount to distribute (must be ≥ MINIMUM_DISTRIBUTE_AMOUNT).
    /// @param fee      RC token amount redirected to the treasury (must be ≤ `amount`).
    function distributeRewards(address receiver, uint256 amount, uint256 fee) external onlyRole(DISTRIBUTOR_ROLE) whenNotPaused {
        if (amount == 0 || amount < MINIMUM_DISTRIBUTE_AMOUNT) {
            revert InvalidAmount();
        }
        if (receiver == address(0)) {
            revert ZeroAddress();
        }

        if (fee > amount) {
            revert InvalidAmount();
        }

        _totalEarned[receiver] += amount;

        IERC20(_rewardCoin).safeTransfer(receiver, amount - fee);
        IERC20(_rewardCoin).safeTransfer(_treasury, fee);
        emit RewardsDistributed(receiver, amount, fee);
    }

    // -------------------------------------------------------------------------
    // Conversion helpers
    // -------------------------------------------------------------------------

    /// @notice Converts a raw stablecoin amount to its whole-USD value and RC equivalent.
    /// @dev Reverts with {RoundAmountRequired} if `amountInStableCoin` is not an exact
    ///      multiple of the stablecoin's denomination (10 ** decimals).
    /// @param amountInStableCoin Raw stablecoin amount (including decimals).
    /// @return funds Struct containing `amountUSD` (whole units) and `amountRC`.
    function convertStableCoins(uint256 amountInStableCoin) public view returns (ConvertedFunds memory funds) {
        uint256 denom = 10 ** IERC20Metadata(_stableCoin).decimals();
        validateExactConvert(amountInStableCoin, denom);

        funds = ConvertedFunds(
            amountInStableCoin / denom,
            (amountInStableCoin * REWARD_TOKENS_PER_USD) / denom
        );
    }

    /// @notice Validates that `amountInStableCoin` converts without remainder.
    /// @dev Reverts with {RoundAmountRequired} if `amountInStableCoin % denom != 0`.
    /// @param amountInStableCoin Raw stablecoin amount to validate.
    /// @param denom              Stablecoin denomination (10 ** decimals).
    function validateExactConvert(uint256 amountInStableCoin, uint256 denom) internal pure {
        if (amountInStableCoin % denom != 0) {
            revert RoundAmountRequired();
        }
        if ((amountInStableCoin * REWARD_TOKENS_PER_USD) % denom != 0) {
            revert RoundAmountRequired();
        }
    }

    // -------------------------------------------------------------------------
    // Admin setters
    // -------------------------------------------------------------------------

    /// @notice Updates the accepted stablecoin address.
    /// @dev Caller must hold DEFAULT_ADMIN_ROLE.
    /// @param stableCoin_ New stablecoin contract address.
    function setStableCoin(address stableCoin_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (stableCoin_ == address(0)) revert ZeroAddress();
        _stableCoin = stableCoin_;
        emit StableCoinSet(stableCoin_);
    }

    /// @notice Updates the reward token address.
    /// @dev Caller must hold DEFAULT_ADMIN_ROLE.
    /// @param rewardCoin_ New reward token contract address.
    function setRewardCoin(address rewardCoin_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (rewardCoin_ == address(0)) revert ZeroAddress();
        _rewardCoin = rewardCoin_;
        emit RewardCoinSet(rewardCoin_);
    }

    /// @notice Updates the minimum stablecoin amount required for a deposit.
    /// @dev Caller must hold DEFAULT_ADMIN_ROLE.
    /// @param minimalDeposit_ New minimum deposit in raw stablecoin units.
    function setMinimalDeposit(uint256 minimalDeposit_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _minimalDeposit = minimalDeposit_;
        emit MinimalDepositSet(minimalDeposit_);
    }

    /// @notice Updates the treasury address that receives distribution fees.
    /// @dev Caller must hold DEFAULT_ADMIN_ROLE.
    /// @param newTreasury New treasury address.
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        _treasury = newTreasury;
        emit TreasurySet(newTreasury);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    /// @notice Returns the address of the accepted stablecoin.
    /// @return Address of the stablecoin contract.
    function stableCoin() external view returns (address) {
        return _stableCoin;
    }

    /// @notice Returns the address of the reward token.
    /// @return Address of the RC token contract.
    function rewardCoin() external view returns (address) {
        return _rewardCoin;
    }

    /// @notice Returns the minimum raw stablecoin amount accepted by `deposit`.
    /// @return Minimum deposit amount in raw stablecoin units.
    function minimalDeposit() external view returns (uint256) {
        return _minimalDeposit;
    }

    /// @notice Returns the cumulative raw stablecoin amount deposited by `user`.
    /// @param user Address to query.
    /// @return Total deposited amount in raw stablecoin units.
    function totalDeposited(address user) external view returns (uint256) {
        return _totalDeposited[user];
    }

    /// @notice Returns the cumulative raw stablecoin amount returned to `user` via cashback.
    /// @param user Address to query.
    /// @return Total withdrawn amount in raw stablecoin units.
    function totalWithdrawn(address user) external view returns (uint256) {
        return _totalWithdrawn[user];
    }

    /// @notice Returns the cumulative RC tokens distributed to `user`.
    /// @param user Address to query.
    /// @return Total earned RC token amount.
    function totalEarned(address user) external view returns (uint256) {
        return _totalEarned[user];
    }

    // -------------------------------------------------------------------------
    // UUPS
    // -------------------------------------------------------------------------

    /// @inheritdoc UUPSUpgradeable
    /// @dev Restricted to UPGRADER_ROLE.
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}