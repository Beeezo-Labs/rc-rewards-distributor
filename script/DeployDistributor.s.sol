// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BeeezoRewardsDistributor} from "../src/BeeezoRewardsDistributor.sol";

contract DeployDistributor is Script {
    function run() public {
        address owner = vm.envAddress("OWNER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address rc = vm.envAddress("RC_ADDRESS");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

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
    }
}