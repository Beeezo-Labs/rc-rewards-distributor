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

contract BeeezoRewardsDistributor is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, RewardDistributorStorage, IBeeezoRewardsDistributor {
    using SafeERC20 for IERC20;

    struct ConvertedFunds {
        uint256 amountUSD;
        uint256 amountRC;
    }

    /// @notice Fixed rate of reward tokens distributed per unit of stablecoin (USD)
    uint256 public constant REWARD_TOKENS_PER_USD = 1000;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

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

    function swapRC(uint256 amount) external whenNotPaused {
        if (amount == 0 || amount < REWARD_TOKENS_PER_USD) {
            revert InvalidAmount();
        }

        uint256 denom = 10 ** IERC20Metadata(_stableCoin).decimals();

        if (amount % REWARD_TOKENS_PER_USD != 0) {
            revert RoundAmountRequired();
        }

        IERC20(_rewardCoin).safeTransferFrom(msg.sender, address(this), amount);
        IRewardCoin(_rewardCoin).burnRewardTokens(amount);

        uint256 amountUSDC = (amount * denom) / REWARD_TOKENS_PER_USD;

        IERC20(_stableCoin).safeTransfer(msg.sender, amountUSDC);

        emit Swap(msg.sender, amount / REWARD_TOKENS_PER_USD, amount);
    }

    function distributeRewards(address receiver, uint256 amount, uint256 fee) external onlyRole(DISTRIBUTOR_ROLE) whenNotPaused {
        if (amount == 0 || amount < REWARD_TOKENS_PER_USD) {
            revert InvalidAmount();
        }
        if (receiver == address(0)) {
            revert ZeroAddress();
        }

        _totalEarned[receiver] += amount;

        IERC20(_rewardCoin).safeTransfer(receiver, amount - fee);
        IERC20(_rewardCoin).safeTransfer(_treasury, fee);
        emit RewardsDistributed(receiver, amount, fee);
    }

    function convertStableCoins(uint256 amountInStableCoin) public view returns (ConvertedFunds memory) {
        uint256 denom = 10 ** IERC20Metadata(_stableCoin).decimals();
        validateExactConvert(amountInStableCoin, denom);

        return ConvertedFunds(
            amountInStableCoin / denom,
            (amountInStableCoin * REWARD_TOKENS_PER_USD) / denom
        );
    }

    function validateExactConvert(uint256 amountInStableCoin, uint256 denom) internal pure {
        if (amountInStableCoin % denom != 0) {
            revert RoundAmountRequired();
        }
        if ((amountInStableCoin * REWARD_TOKENS_PER_USD) % denom != 0) {
            revert RoundAmountRequired();
        }
    }

    function setStableCoin(address stableCoin_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _stableCoin = stableCoin_;
    }

    function setRewardCoin(address rewardCoin_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rewardCoin = rewardCoin_;
    }

    function setMinimalDeposit(uint256 minimalDeposit_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _minimalDeposit = minimalDeposit_;
    }

    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _treasury = newTreasury;
    }

    function stableCoin() external view returns (address) {
        return _stableCoin;
    }

    function rewardCoin() external view returns (address) {
        return _rewardCoin;
    }

    function minimalDeposit() external view returns (uint256) {
        return _minimalDeposit;
    }

    function totalDeposited(address user) external view returns (uint256) {
        return _totalDeposited[user];
    }

    function totalWithdrawn(address user) external view returns (uint256) {
        return _totalWithdrawn[user];
    }

    function totalEarned(address user) external view returns (uint256) {
        return _totalEarned[user];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}