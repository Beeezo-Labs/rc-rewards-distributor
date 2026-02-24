// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import {BeeezoRewardsDistributor} from "../src/BeeezoRewardsDistributor.sol";

/// @dev Required env vars:
///   PRIVATE_KEY    — private key of an account holding UPGRADER_ROLE on the proxy
///   PROXY_ADDRESS  — address of the existing BeeezoRewardsDistributor proxy
contract UpgradeDistributor is Script {
    function run() public {
        address proxy = vm.envAddress("PROXY_ADDRESS");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        BeeezoRewardsDistributor newImplementation = new BeeezoRewardsDistributor();
        BeeezoRewardsDistributor(proxy).upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();

        console.log("New implementation deployed to:", address(newImplementation));
        console.log("Proxy upgraded at:             ", proxy);
    }
}
