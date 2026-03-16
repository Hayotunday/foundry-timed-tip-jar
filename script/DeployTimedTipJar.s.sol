// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {TimedTipJar} from "src/TimedTipJar.sol";

contract DeployTimedTipJar is Script {
  TimedTipJar public timedTipJar;
  address public constant WITHDRAWER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  uint256 public constant WITHDRAW_DELAY = 1 days;

  function run() external returns (TimedTipJar) {
    vm.startBroadcast();
    timedTipJar = new TimedTipJar(WITHDRAWER, WITHDRAW_DELAY);
    vm.stopBroadcast();
    return timedTipJar;
  }
}
