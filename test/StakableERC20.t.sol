// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { StakableERC20 } from "../src/StakableERC20.sol";

contract StakableERC20Test is Test {
  address public immutable OWNER = makeAddr("owner");
  address public immutable REFERAL = makeAddr("referal");
  address public immutable USER = makeAddr("user");

  uint256 public constant USER_MINT_AMOUNT = 1000 ether;
  uint256 public constant STAKE_AMOUNT = 100 ether;
  uint256 public constant STAKE_PERCENT = 50;
  uint256 public constant REFERAL_PERCENT = 10;

  StakableERC20 public token;

  function setUp() public {
    vm.startPrank(OWNER);
    token = new StakableERC20(REFERAL_PERCENT, STAKE_PERCENT);
    vm.stopPrank();
  }

  function test_mintTo() public {
    vm.startPrank(OWNER);
    token.mintTo(USER, USER_MINT_AMOUNT);
    vm.stopPrank();
    assertEq(token.balanceOf(USER), USER_MINT_AMOUNT);
  }

  modifier stakable() {
    vm.startPrank(OWNER);
    token.mintTo(USER, USER_MINT_AMOUNT);
    vm.stopPrank();

    vm.startPrank(USER);
    token.approve(address(token), STAKE_AMOUNT);
    vm.stopPrank();
    _;
  }

  function test_stakeDataSetsCorrectly() public stakable {
    vm.startPrank(USER);
    token.stake(STAKE_AMOUNT, REFERAL);

    StakableERC20.StakeInfo[] memory stakes = token.getStakes();
    vm.stopPrank();
    assertEq(stakes.length, 1);
    assertEq(stakes[0].startTimestamp, block.timestamp);
    assertEq(stakes[0].endTimestamp, 0);
    assertEq(stakes[0].amount, STAKE_AMOUNT);
    assertEq(stakes[0].claimed, 0);
    assertEq(stakes[0].percent, STAKE_PERCENT);
    assertEq(stakes[0].referal, REFERAL);
    assertEq(token.balanceOf(address(token)), STAKE_AMOUNT);
  }

  function test_stakeRewardCalculations() public stakable {
    vm.startPrank(USER);
    token.stake(STAKE_AMOUNT, REFERAL);

    uint256 stakeStartTimestamp = block.timestamp;
    vm.warp(stakeStartTimestamp + 365 days);
    uint256 expectedReward = 45 ether;
    uint256 expectedReferalReward = 5 ether;

    StakableERC20.StakeInfo[] memory stakes = token.getStakes();

    (uint256 reward, uint256 referalReward) = token.calculateReward(stakes[0]);
    vm.stopPrank();

    assertEq(reward, expectedReward);
    assertEq(expectedReferalReward, referalReward);
  }

  function test_stakePayouts() public stakable {
    vm.startPrank(USER);
    token.stake(STAKE_AMOUNT, REFERAL);

    uint256 expectedReward = 45 ether;
    uint256 expectedReferalReward = 5 ether;
    uint256 stakeStartTimestamp = block.timestamp;
    vm.warp(stakeStartTimestamp + 365 days);

    uint256 userBalanceBefore = token.balanceOf(USER);
    uint256 referalBalanceBefore = token.balanceOf(REFERAL);

    token.claimStakeReward(0);

    uint256 userBalanceAfter = token.balanceOf(USER);
    uint256 referalBalanceAfter = token.balanceOf(REFERAL);

    StakableERC20.StakeInfo[] memory stakes = token.getStakes();

    assertEq(stakes[0].claimed, expectedReward + expectedReferalReward);
    assertEq(userBalanceAfter - userBalanceBefore, expectedReward);
    assertEq(referalBalanceAfter - referalBalanceBefore, expectedReferalReward);
  }
}
