// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title StableCoinMock
/// @notice Test double for a 6-decimal stablecoin (e.g. USDC).
/// @dev For use in local and testnet environments only. Mint is unrestricted.
contract StableCoinMock is ERC20, ERC20Burnable {
    constructor() ERC20("USDCMock", "USDCMock") {}

    /// @notice Mints `amount` tokens to `to`. No access control — test use only.
    /// @param to     Recipient address.
    /// @param amount Raw token amount to mint (6 decimals).
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /// @notice Returns 6, matching real USDC decimals.
    /// @return decimals_ Always 6.
    function decimals() public pure override returns (uint8 decimals_) {
        return 6;
    }
}