pragma solidity 0.8.30;

/**
 * @title IRCToken
 * @author Beeezo
 * @dev Interface for the RCToken contract, defining core functions for minting, burning,
 *      and managing authorized distributors.
 */
interface IRewardCoin {
    function mint(uint256 amount) external;
    function burnRewardTokens(uint256 amount) external;
}