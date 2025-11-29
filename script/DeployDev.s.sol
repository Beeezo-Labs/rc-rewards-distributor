// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BeeezoRewardsDistributor } from "../src/BeeezoRewardsDistributor.sol";

import { RewardCoinMock } from "../src/mock/RewardCoinMock.sol";
import { StableCoinMock } from "../src/mock/StableCoinMock.sol";

contract DeployDistributor is Script {
    function run() public {
        address owner = vm.envAddress("OWNER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        RewardCoinMock rc = new RewardCoinMock();
        StableCoinMock usdc = new StableCoinMock();

        BeeezoRewardsDistributor implementation = new BeeezoRewardsDistributor();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            ""
        );

        BeeezoRewardsDistributor distributor = BeeezoRewardsDistributor(address(proxy));
        distributor.initialize(
            owner,
            owner,
            owner,
            admin,
            address(usdc),
            address(rc),
            10000000
        );

        vm.stopBroadcast();

        console.log("Distributor deployed to: ", address(distributor));
        console.log("RewardCoin deployed to: ", address(rc));
        console.log("StableCoin deployed to ", address(usdc));
    }
}