// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract RewardCoinMock is ERC20, ERC20Burnable {
    constructor() ERC20("RewardCoinMock", "RCMock") {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function burnRewardTokens(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}