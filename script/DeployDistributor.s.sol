// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BeeezoRewardsDistributor} from "../src/BeeezoRewardsDistributor.sol";

/// @dev Required env vars:
///   PRIVATE_KEY          — deployer private key (must be funded)
///   DEFAULT_ADMIN_ADDRESS — granted DEFAULT_ADMIN_ROLE and used as initial treasury
///   PAUSER_ADDRESS        — granted PAUSER_ROLE
///   UPGRADER_ADDRESS      — granted UPGRADER_ROLE
///   DISTRIBUTOR_ADDRESS   — granted DISTRIBUTOR_ROLE
///   STABLE_COIN_ADDRESS   — accepted stablecoin (e.g. USDC)
///   REWARD_COIN_ADDRESS   — RC reward token
///   MINIMAL_DEPOSIT       — minimum deposit in raw stablecoin units
contract DeployDistributor is Script {
    function run() public {
        address defaultAdmin = vm.envAddress("DEFAULT_ADMIN_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address upgrader = vm.envAddress("UPGRADER_ADDRESS");
        address distributor = vm.envAddress("DISTRIBUTOR_ADDRESS");
        address stableCoin = vm.envAddress("STABLE_COIN_ADDRESS");
        address rewardCoin = vm.envAddress("REWARD_COIN_ADDRESS");
        uint256 minimalDeposit = vm.envUint("MINIMAL_DEPOSIT");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        BeeezoRewardsDistributor implementation = new BeeezoRewardsDistributor();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                BeeezoRewardsDistributor.initialize,
                (defaultAdmin, pauser, upgrader, distributor, stableCoin, rewardCoin, minimalDeposit)
            )
        );

        vm.stopBroadcast();

        console.log("Implementation deployed to:", address(implementation));
        console.log("Proxy deployed to:         ", address(proxy));
    }
}
