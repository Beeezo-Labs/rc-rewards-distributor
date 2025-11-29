// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BeeezoRewardsDistributor } from "../src/BeeezoRewardsDistributor.sol";

import { RewardCoinMock } from "../src/mock/RewardCoinMock.sol";
import { StableCoinMock } from "../src/mock/StableCoinMock.sol";

contract Deposit is Script {
    function run() public {
        address owner = vm.envAddress("OWNER_ADDRESS");

        address rcAddr = vm.envAddress("REWARD_COIN");
        address usdcAddr = vm.envAddress("STABLE_COIN");
        address distributorAddr = vm.envAddress("DISTRIBUTOR");

        RewardCoinMock rc = RewardCoinMock(rcAddr);
        StableCoinMock usdc = StableCoinMock(usdcAddr);
        BeeezoRewardsDistributor distributor = BeeezoRewardsDistributor(distributorAddr);

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        usdc.mint(owner, 1000 ether);
        usdc.approve(address(distributor), type(uint256).max);

        distributor.deposit(100 * (10 ** usdc.decimals()));

        vm.stopBroadcast();
    }
}