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
    address internal user = makeAddr ("user");

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

    function testConstructorAndInitializer() public {
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

        uint256 investorBalanceAfter = usdc.balanceOf(deployer);
        uint256 distributorBalanceAfter = usdc.balanceOf(address(distributor));
        uint256 investorRcBalanceAfter = rc.balanceOf(deployer);
        uint256 distributorRcBalanceAfter = rc.balanceOf(address(distributor));

        assertEq(investorBalanceAfter, investorBalanceBefore - depositAmount);
        assertEq(distributorBalanceAfter, distributorBalanceBefore + depositAmount);
        assertEq(investorRcBalanceAfter, investorRcBalanceBefore); // still 0
        assertEq(distributorRcBalanceAfter, distributorRcBalanceBefore + depositAmountRc);

        assertEq(distributor.totalDeposited(deployer), depositAmount);
    }

    function testDepositRevertedWhenAmountLessThanMinimal() public {
        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(deployer);
        distributor.deposit(minimalDeposit - 1);
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

        uint256 investorBalanceAfter = usdc.balanceOf(deployer);
        uint256 distributorBalanceAfter = usdc.balanceOf(address(distributor));
        uint256 investorRcBalanceAfter = rc.balanceOf(deployer);
        uint256 distributorRcBalanceAfter = rc.balanceOf(address(distributor));

        assertEq(investorBalanceAfter, investorBalanceBefore + depositAmount);
        assertEq(distributorBalanceAfter, distributorBalanceBefore - depositAmount);
        assertEq(investorRcBalanceAfter, investorRcBalanceBefore); // still 0
        assertEq(distributorRcBalanceAfter, distributorRcBalanceBefore - depositAmountRc);

        assertEq(distributor.totalDeposited(deployer), depositAmount); // do not change
        assertEq(distributor.totalWithdrawn(deployer), depositAmount);
    }

    function testCashbackRevertedWhenAmountBiggerThanDeposited() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        vm.prank(deployer);
        distributor.cashback(deployer, depositAmount + 1);
    }

    function testCashbackRevertedWhenZeroAmount() public {
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

        uint256 userBalanceAfter = rc.balanceOf(user);
        uint256 distributorBalanceAfter = rc.balanceOf(address(distributor));
        uint256 treasuryBalanceAfter = rc.balanceOf(deployer);

        assertEq(userBalanceAfter, userBalanceBefore + (rewardsAmount - gasFees));
        assertEq(distributorBalanceAfter, distributorBalanceBefore - rewardsAmount);
        assertEq(treasuryBalanceAfter, treasuryBalanceBefore + gasFees);
        assertEq(distributor.totalEarned(user), rewardsAmount);
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

    function testDistributeRewardsRevertedWhenAmountLessThanMinimal() public {
        vm.prank(beeezoAdmin);
        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        distributor.distributeRewards(user, rcPerUsd - 1, gasFees);
    }

    function testDistributeRewardsRevertedWhenZeroAddress() public {
        vm.prank(beeezoAdmin);
        vm.expectRevert(IBeeezoRewardsDistributor.ZeroAddress.selector);
        distributor.distributeRewards(address(0), rewardsAmount, gasFees);
    }

    function testSwapRc() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        uint256 userBalanceRcBefore = rc.balanceOf(user);
        uint256 userBalanceUsdcBefore = usdc.balanceOf(user);
        uint256 distributorBalanceRcBefore= rc.balanceOf(address(distributor));
        uint256 distributorBalanceUsdcBefore = usdc.balanceOf(address(distributor));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IBeeezoRewardsDistributor.Swap(user, (swapAmount / rcPerUsd), swapAmount);

        vm.prank(user);
        distributor.swapRC(swapAmount);

        uint256 userBalanceRcAfter = rc.balanceOf(user);
        uint256 userBalanceUsdcAfter = usdc.balanceOf(user);
        uint256 distributorBalanceRcAfter= rc.balanceOf(address(distributor));
        uint256 distributorBalanceUsdcAfter = usdc.balanceOf(address(distributor));

        assertEq(userBalanceRcAfter, userBalanceRcBefore - swapAmount);
        assertEq(_toUsd(userBalanceUsdcAfter), _toUsd(userBalanceUsdcBefore) + (swapAmount / rcPerUsd));
        assertEq(distributorBalanceRcBefore, distributorBalanceRcAfter); // no changes here
        assertEq(_toUsd(distributorBalanceUsdcAfter), _toUsd(distributorBalanceUsdcBefore) - (swapAmount / rcPerUsd));
    }

    function testSwapRevertedWhenZeroAmount() public {
        vm.prank(deployer);
        distributor.deposit(depositAmount);

        vm.prank(beeezoAdmin);
        distributor.distributeRewards(user, rewardsAmount, gasFees);

        vm.prank(user);
        vm.expectRevert(IBeeezoRewardsDistributor.InvalidAmount.selector);
        distributor.swapRC(0);
    }

    function testSwapRevertedWhenAmountLessThanUsd() public {

    }

    function _toUsd(uint256 usdcAmount) internal view returns (uint256) {
        return usdcAmount / 10 ** usdc.decimals();
    }
}