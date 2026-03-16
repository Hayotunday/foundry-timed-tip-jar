// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimedTipJar} from "src/TimedTipJar.sol";
import {DeployTimedTipJar} from "script/DeployTimedTipJar.s.sol";

contract TimedTipJarTest is Test {
  TimedTipJar public timedTipJar;
  address public immutable IUSER = makeAddr("IUSER");
  address public immutable IUSER1 = makeAddr("IUSER1");
  address public immutable IUSER2 = makeAddr("IUSER2");

  function setUp() public {
    timedTipJar = (new DeployTimedTipJar()).run();
  }

  function testDepositTip() public {
    vm.startPrank(IUSER);
    uint256 tip = 1 ether;
    vm.deal(IUSER, tip);
    uint256 tipId = timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    // Verify that the tip was deposited correctly
    (address tipper, uint256 ethAmount,) = timedTipJar.tips(tipId);
    assertEq(tipper, IUSER);
    assertEq(ethAmount, tip);
  }

  function testWithdrawTip() public {
    vm.startPrank(IUSER);
    uint256 tip = 1 ether;
    vm.deal(IUSER, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(timedTipJar.withdrawer());
    vm.warp(block.timestamp + 1 days + 1); // Move time forward to ensure tips are unlocked
    timedTipJar.withdrawTips(50);
    // Verify that the tip was withdrawn correctly
    uint256 contractBalance = address(timedTipJar).balance;
    uint256 withdrawerBalance = address(timedTipJar.withdrawer()).balance;
    assertEq(contractBalance, 0);
    assertEq(withdrawerBalance, tip);
    vm.stopPrank();
  }

  function testOnlyWithdrawerAddrCanWithdrawTips() public {
    vm.startPrank(IUSER);
    uint256 tip = 1 ether;
    vm.deal(IUSER, tip);
    timedTipJar.depositTip{value: tip}();

    vm.warp(block.timestamp + 1 days + 1); // Move time forward to ensure tips are unlocked

    vm.expectRevert(TimedTipJar.TimedTipJar__OnlyWithdrawerCanWithdraw.selector);
    timedTipJar.withdrawTips(50);
    vm.stopPrank();
  }

  function testWithdrawableTipMustBeMoreThanZero() public {
    vm.startPrank(IUSER);
    uint256 tip = 1 ether;
    vm.deal(IUSER, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(timedTipJar.withdrawer());

    vm.expectRevert(TimedTipJar.TimedTipJar__WithdrawableTipMustBeMoreThanZero.selector);
    timedTipJar.withdrawTips(50);
    vm.stopPrank();
  }

  function testDepositAmountMustBeMoreThanZero() public {
    vm.startPrank(IUSER);
    vm.expectRevert(TimedTipJar.TimedTipJar__TipAmountMustBeMoreThanZero.selector);
    timedTipJar.depositTip{value: 0}();
    vm.stopPrank();
  }

  function testGetTipCount() public {
    uint256 tip = 1 ether;

    vm.startPrank(IUSER);
    vm.deal(IUSER, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(IUSER1);
    vm.deal(IUSER1, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(IUSER2);
    vm.deal(IUSER2, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    uint256 tipCount = timedTipJar.getTipCount();
    assertEq(tipCount, 3);
  }

  function testGetTipIdAtIndex() public {
    uint256 tip = 1 ether;

    vm.startPrank(IUSER);
    vm.deal(IUSER, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(IUSER1);
    vm.deal(IUSER1, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(IUSER2);
    vm.deal(IUSER2, tip);
    uint256 tipId = timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    uint256 tipData = timedTipJar.getTipIdAtIndex(2);
    assertEq(tipData, tipId);
  }

  function testGetTip() public {
    uint256 tip = 1 ether;

    vm.startPrank(IUSER);
    vm.deal(IUSER, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    vm.startPrank(IUSER1);
    vm.deal(IUSER1, tip);
    uint256 tipId = timedTipJar.depositTip{value: tip}();
    TimedTipJar.Tip memory tipInfo = TimedTipJar.Tip(IUSER1, tip, block.timestamp + timedTipJar.withdrawalDelay());
    vm.stopPrank();

    vm.startPrank(IUSER2);
    vm.deal(IUSER2, tip);
    timedTipJar.depositTip{value: tip}();
    vm.stopPrank();

    TimedTipJar.Tip memory tipData = timedTipJar.getTip(tipId);
    assertEq(keccak256(abi.encode(tipData)), keccak256(abi.encode(tipInfo)));
  }
}
