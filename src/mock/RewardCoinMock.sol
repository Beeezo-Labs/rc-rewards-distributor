// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title RewardCoinMock
/// @notice Test double for the RC reward token, implementing {IRewardCoin}.
/// @dev For use in local and testnet environments only. RC has 0 decimals, so
///      all amounts are whole integer token counts. Mint is unrestricted.
contract RewardCoinMock is ERC20, ERC20Burnable {
    constructor() ERC20("RewardCoinMock", "RCMock") {}

    /// @notice Mints `amount` RC tokens to the caller. No access control — test use only.
    /// @param amount Number of RC tokens to mint.
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    /// @notice Burns `amount` RC tokens from the caller's balance.
    /// @dev Implements {IRewardCoin.burnRewardTokens}.
    /// @param amount Number of RC tokens to burn.
    function burnRewardTokens(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Returns 0, reflecting that RC tokens are whole-unit reward points.
    /// @return decimals_ Always 0.
    function decimals() public pure override returns (uint8 decimals_) {
        return 0;
    }
}