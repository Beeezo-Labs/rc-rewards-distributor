// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {StableCoinMock} from "../src/mock/StableCoinMock.sol";
import {RewardCoinMock} from "../src/mock/RewardCoinMock.sol";
import {BeeezoRewardsDistributor} from "../src/BeeezoRewardsDistributor.sol";
import {IBeeezoRewardsDistributor} from "../src/interfaces/IBeeezoRewardsDistributor.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract BeeezoRewardsDistributorUnitTest is Test {
    address internal deployer = makeAddr("deployer");
    address internal upgrader = makeAddr("upgrader");
    address internal pauser = makeAddr("pauser");
    address internal beeezoAdmin = makeAddr("beeezoAdmin");
    address internal user = makeAddr("user");

    StableCoinMock internal usdc = new StableCoinMock();
    RewardCoinMock internal rc = new RewardCoinMock();
    BeeezoRewardsDistributor internal distributor;

    uint256 internal rcPerUsd = 1000;
    uint256 internal minimalDeposit = 10 * 10 ** usdc.decimals();
    uint256 internal depositAmount = 1000 * 10 ** usdc.decimals();
    uint256 internal rewardsAmount = 5000;
    uint256 internal swapAmount = 2000;
    uint256 internal gasFees = 2;

    uint256 internal depositAmountRc = (depositAmount / (10 ** usdc.decimals())) * rcPerUsd;
    uint256 internal depositAmountUsd = depositAmount / (10 ** usdc.decimals());

    function setUp() public {
        vm.startPrank(deployer);
        BeeezoRewardsDistributor implementation = new BeeezoRewardsDistributor();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            ""
        );

        distributor = BeeezoRewardsDistributor(address(proxy));
        distributor.initialize(
            deployer,
            pauser,
            upgrader,
            beeezoAdmin,
            address(usdc),
            address(rc),
            minimalDeposit
        );

        usdc.mint(deployer, depositAmount);
        usdc.approve(address(distributor), type(uint256).max);
        vm.stopPrank();

        vm.prank(user);
        rc.approve(address(distributor), type(uint256).max);
    }

    function testConstructorAndInitializer() public view {
        assertTrue(distributor.hasRole(distributor.DEFAULT_ADMIN_ROLE(), deployer));
        assertTrue(distributor.hasRole(distributor.PAUSER_ROLE(), pauser));
        assertTrue(distributor.hasRole(distributor.UPGRADER_ROLE(), upgrader));
        assertTrue(distributor.hasRole(distributor.DISTRIBUTOR_ROLE(), beeezoAdmin));

        assertEq(distributor.rewardCoin(), address(rc));
        assertEq(distributor.stableCoin(), address(usdc));
        assertEq(distributor.minimalDeposit(), minimalDeposit);
    }

    function testPause() public {
        assertFalse(distributor.paused());

        vm.prank(pauser);
        distributor.pause();

        assertTrue(distributor.paused());
    }

    function testPauseRevertedIfCallerNotPauser() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                deployer,
                distributor.PAUSER_ROLE()
            )
        );
        vm.prank(deployer);
        distributor.pause();
    }

    function testPauseRevertedIfContractAlreadyPaused() public {
        vm.prank(pauser);
        distributor.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(pauser);
        distributor.pause();
    }

    function testUnpause() public {
        vm.prank(pauser);
        distributor.pause();

        assertTrue(distributor.paused());

        vm.prank(pauser);
        distributor.unpause();

        assertFalse(distributor.paused());
    }

    function testUnpauseRevertedIfCallerNotPauser() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                deployer,
                distributor.PAUSER_ROLE()
            )
        );
        vm.prank(deployer);
        distributor.unpause();
    }

    function testPauseRevertedIfContractNotPaused() public {
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        vm.prank(pauser);
        distributor.unpause();
    }

    function testDeposit() public {
        uint256 investorBalanceBefore = usdc.balanceOf(deployer);
        uint256 distributorBalanceBefore = usdc.balanceOf(address(distributor));
        uint256 investorRcBalanceBefore = rc.balanceOf(deployer);
        uint256 distributorRcBalanceBefore = rc.balanceOf(address(distributor));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IBeeezoRewardsDistributor.Deposit(deployer, depositAmountUsd, depositAmountRc);

        vm.prank(deployer);
        distributor.deposit(depositAmount);

        assertEq(usdc.balanceOf(deployer), investorBalanceBefore - depositAmount);
        assertEq(usdc.balanceOf(address(distributor)), distributorBalanceBefore + depositAmount);
        assertEq(rc.balanceOf(deployer), investorRcBalanceBefore);
        assertEq(rc.balanceOf(address(distributor)), distributorRcBalanceBefore + depositAmountRc);
        assertEq(distributor.totalDeposited(deployer), depositAmount);
    }

    function testDepositRevertedWhenAmountLessThanMinimal() public {
        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(deployer);
        distributor.deposit(minimalDeposit - 1);
    }

    function testDepositRevertedWhenNonRoundAmount() public {
        uint256 nonRoundAmount = minimalDeposit + 1;
        usdc.mint(deployer, nonRoundAmount);

        vm.expectRevert(IBeeezoRewardsDistributor.RoundAmountRequired.selector);
        vm.prank(deployer);
        distributor.deposit(nonRoundAmount);
    }

    function testDepositRevertedWhenContractPaused() public {
        vm.prank(pauser);
        distributor.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(deployer);
        distributor.deposit(depositAmount);
    }

    function testCashback() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        uint256 investorBalanceBefore = usdc.balanceOf(deployer);
        uint256 distributorBalanceBefore = usdc.balanceOf(address(distributor));
        uint256 investorRcBalanceBefore = rc.balanceOf(deployer);
        uint256 distributorRcBalanceBefore = rc.balanceOf(address(distributor));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IBeeezoRewardsDistributor.Cashback(deployer, depositAmountUsd, depositAmountRc);

        vm.prank(deployer);
        distributor.cashback(deployer, depositAmount);

        assertEq(usdc.balanceOf(deployer), investorBalanceBefore + depositAmount);
        assertEq(usdc.balanceOf(address(distributor)), distributorBalanceBefore - depositAmount);
        assertEq(rc.balanceOf(deployer), investorRcBalanceBefore);
        assertEq(rc.balanceOf(address(distributor)), distributorRcBalanceBefore - depositAmountRc);
        assertEq(distributor.totalDeposited(deployer), depositAmount);
        assertEq(distributor.totalWithdrawn(deployer), depositAmount);
    }

    function testCashbackRevertedWhenAmountBiggerThanDeposited() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        uint256 tooMuch = depositAmount + 10 ** usdc.decimals();

        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(deployer);
        distributor.cashback(deployer, tooMuch);
    }

    function testCashbackRevertedWhenZeroAmount() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(deployer);
        distributor.cashback(deployer, 0);
    }

    function testCashbackRevertedWhenZeroAddress() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.expectRevert(IBeeezoRewardsDistributor.ZeroAddress.selector);
        vm.prank(deployer);
        distributor.cashback(address(0), depositAmount);
    }

    function testCashbackRevertedWhenCallerNotOwner() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                distributor.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        distributor.cashback(user, depositAmount);
    }

    function testCashbackRevertedWhenContractPaused() public {
        vm.prank(pauser);
        distributor.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(deployer);
        distributor.cashback(deployer, depositAmount);
    }

    function testDistributeRewards() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        uint256 userBalanceBefore = rc.balanceOf(user);
        uint256 distributorBalanceBefore = rc.balanceOf(address(distributor));
        uint256 treasuryBalanceBefore = rc.balanceOf(deployer);

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IBeeezoRewardsDistributor.RewardsDistributed(user, rewardsAmount, gasFees);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        assertEq(rc.balanceOf(user), userBalanceBefore + (rewardsAmount - gasFees));
        assertEq(rc.balanceOf(address(distributor)), distributorBalanceBefore - rewardsAmount);
        assertEq(rc.balanceOf(deployer), treasuryBalanceBefore + gasFees);
        assertEq(distributor.totalEarned(user), rewardsAmount);
    }

    function testDistributeRewardsRevertedWhenFeeExceedsAmount() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, rewardsAmount + 1);
    }

    function testDistributeRewardsRevertedWhenCallerNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                distributor.DISTRIBUTOR_ROLE()
            )
        );
        vm.prank(user);
        distributor.distributeRewards(user, rewardsAmount, gasFees);
    }

    function testDistributeRewardsRevertedWhenContractPaused() public {
        vm.prank(pauser);
        distributor.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);
    }

    function testDistributeRewardsRevertedWhenZeroAddress() public {
        vm.expectRevert(IBeeezoRewardsDistributor.ZeroAddress.selector);
        vm.prank(beeezoAdmin);
        distributor.distributeRewards(address(0), rewardsAmount, gasFees);
    }

    function testDistributeRewardsRevertedWhenAmountBelowMinimum() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        uint256 belowMinimum = distributor.MINIMUM_DISTRIBUTE_AMOUNT() - 1;

        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, belowMinimum, 0);
    }

    function testSetStableCoin() public {
        address newStableCoin = makeAddr("newStableCoin");

        vm.expectEmit(true, false, false, false, address(distributor));
        emit IBeeezoRewardsDistributor.StableCoinSet(newStableCoin);

        vm.prank(deployer);
        distributor.setStableCoin(newStableCoin);

        assertEq(distributor.stableCoin(), newStableCoin);
    }

    function testSetStableCoinRevertedWhenZeroAddress() public {
        vm.expectRevert(IBeeezoRewardsDistributor.ZeroAddress.selector);
        vm.prank(deployer);
        distributor.setStableCoin(address(0));
    }

    function testSetStableCoinRevertedWhenCallerNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                distributor.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        distributor.setStableCoin(makeAddr("newStableCoin"));
    }

    function testSetRewardCoin() public {
        address newRewardCoin = makeAddr("newRewardCoin");

        vm.expectEmit(true, false, false, false, address(distributor));
        emit IBeeezoRewardsDistributor.RewardCoinSet(newRewardCoin);

        vm.prank(deployer);
        distributor.setRewardCoin(newRewardCoin);

        assertEq(distributor.rewardCoin(), newRewardCoin);
    }

    function testSetRewardCoinRevertedWhenZeroAddress() public {
        vm.expectRevert(IBeeezoRewardsDistributor.ZeroAddress.selector);
        vm.prank(deployer);
        distributor.setRewardCoin(address(0));
    }

    function testSetRewardCoinRevertedWhenCallerNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                distributor.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        distributor.setRewardCoin(makeAddr("newRewardCoin"));
    }

    function testSetMinimalDeposit() public {
        uint256 newMinimalDeposit = minimalDeposit * 2;

        vm.expectEmit(false, false, false, true, address(distributor));
        emit IBeeezoRewardsDistributor.MinimalDepositSet(newMinimalDeposit);

        vm.prank(deployer);
        distributor.setMinimalDeposit(newMinimalDeposit);

        assertEq(distributor.minimalDeposit(), newMinimalDeposit);
    }

    function testSetMinimalDepositRevertedWhenCallerNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                distributor.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        distributor.setMinimalDeposit(minimalDeposit * 2);
    }

    function testSetTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.expectEmit(true, false, false, false, address(distributor));
        emit IBeeezoRewardsDistributor.TreasurySet(newTreasury);

        vm.prank(deployer);
        distributor.setTreasury(newTreasury);

        vm.prank(deployer);
        distributor.deposit(depositAmount);

        uint256 newTreasuryRcBefore = rc.balanceOf(newTreasury);
        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);
        assertEq(rc.balanceOf(newTreasury), newTreasuryRcBefore + gasFees);
    }

    function testSetTreasuryRevertedWhenZeroAddress() public {
        vm.expectRevert(IBeeezoRewardsDistributor.ZeroAddress.selector);
        vm.prank(deployer);
        distributor.setTreasury(address(0));
    }

    function testSetTreasuryRevertedWhenCallerNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                distributor.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user);
        distributor.setTreasury(makeAddr("newTreasury"));
    }

    function testSwapRc() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        uint256 userBalanceRcBefore = rc.balanceOf(user);
        uint256 userBalanceUsdcBefore = usdc.balanceOf(user);
        uint256 distributorBalanceRcBefore = rc.balanceOf(address(distributor));
        uint256 distributorBalanceUsdcBefore = usdc.balanceOf(address(distributor));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IBeeezoRewardsDistributor.Swap(user, swapAmount * distributor.RAW_USDC_PER_REWARD_TOKEN(), swapAmount);

        vm.prank(user);
        distributor.swapRC(swapAmount);

        uint256 expectedUsdc = swapAmount * distributor.RAW_USDC_PER_REWARD_TOKEN();
        assertEq(rc.balanceOf(user), userBalanceRcBefore - swapAmount);
        assertEq(usdc.balanceOf(user), userBalanceUsdcBefore + expectedUsdc);
        assertEq(rc.balanceOf(address(distributor)), distributorBalanceRcBefore);
        assertEq(usdc.balanceOf(address(distributor)), distributorBalanceUsdcBefore - expectedUsdc);
    }

    function testFuzzSwapRc(uint256 amount) public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        uint256 maxByUserRc = rc.balanceOf(user);
        uint256 maxByDistributorUsdc = usdc.balanceOf(address(distributor)) / distributor.RAW_USDC_PER_REWARD_TOKEN();
        amount = bound(amount, 1, min(maxByUserRc, maxByDistributorUsdc));

        uint256 userBalanceRcBefore = rc.balanceOf(user);
        uint256 userBalanceUsdcBefore = usdc.balanceOf(user);
        uint256 distributorBalanceRcBefore = rc.balanceOf(address(distributor));
        uint256 distributorBalanceUsdcBefore = usdc.balanceOf(address(distributor));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IBeeezoRewardsDistributor.Swap(user, amount * distributor.RAW_USDC_PER_REWARD_TOKEN(), amount);

        vm.prank(user);
        distributor.swapRC(amount);

        uint256 expectedUsdc = amount * distributor.RAW_USDC_PER_REWARD_TOKEN();
        assertEq(rc.balanceOf(user), userBalanceRcBefore - amount);
        assertEq(usdc.balanceOf(user), userBalanceUsdcBefore + expectedUsdc);
        assertEq(rc.balanceOf(address(distributor)), distributorBalanceRcBefore);
        assertEq(usdc.balanceOf(address(distributor)), distributorBalanceUsdcBefore - expectedUsdc);
    }

    function testSwapRevertedWhenZeroAmount() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(user);
        distributor.swapRC(0);
    }

    function testSwapRevertedWhenContractPaused() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        vm.prank(pauser);
        distributor.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(user);
        distributor.swapRC(swapAmount);
    }

    function testUpgrade() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        uint256 totalDepositedBefore = distributor.totalDeposited(deployer);
        uint256 totalEarnedBefore = distributor.totalEarned(user);
        address stableCoinBefore = distributor.stableCoin();
        address rewardCoinBefore = distributor.rewardCoin();
        uint256 minimalDepositBefore = distributor.minimalDeposit();

        BeeezoRewardsDistributor newImplementation = new BeeezoRewardsDistributor();

        vm.prank(upgrader);
        distributor.upgradeToAndCall(address(newImplementation), "");

        assertEq(distributor.totalDeposited(deployer), totalDepositedBefore);
        assertEq(distributor.totalEarned(user), totalEarnedBefore);
        assertEq(distributor.stableCoin(), stableCoinBefore);
        assertEq(distributor.rewardCoin(), rewardCoinBefore);
        assertEq(distributor.minimalDeposit(), minimalDepositBefore);

        usdc.mint(deployer, depositAmount);
        vm.prank(deployer);
        usdc.approve(address(distributor), type(uint256).max);
        vm.prank(deployer);
        distributor.deposit(depositAmount);
        assertEq(distributor.totalDeposited(deployer), totalDepositedBefore + depositAmount);
    }

    function testUpgradeRevertedWhenCallerNotUpgrader() public {
        BeeezoRewardsDistributor newImplementation = new BeeezoRewardsDistributor();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                deployer,
                distributor.UPGRADER_ROLE()
            )
        );
        vm.prank(deployer);
        distributor.upgradeToAndCall(address(newImplementation), "");
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
