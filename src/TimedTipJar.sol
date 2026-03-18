// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract TimedTipJar {
  // --- Custom Errors ---

  error TimedTipJar__TipAmountMustBeMoreThanZero();
  error TimedTipJar__OnlyWithdrawerCanWithdraw();
  error TimedTipJar__WithdrawableTipMustBeMoreThanZero();
  error TimedTipJar__TipsWithdrawalFailed();

  // --- State Variables ---

  address public immutable withdrawer;
  uint256 public immutable withdrawalDelay;

  // --- Data Structures ---

  struct Tip {
    address tipper;
    uint256 ethAmount;
    uint256 lockedUntil;
  }

  // --- Enumerable Set for Tips ---
  // This pattern allows for efficient addition and removal of tips,
  // preventing issues with gas limits when the number of tips grows large.

  // Mapping from a unique tip ID to the Tip struct.
  mapping(uint256 => Tip) public tips;
  // Array of active tip IDs.
  uint256[] private tipIds;
  // Mapping from a tip ID to its index in the tipIds array.
  mapping(uint256 => uint256) private tipIdToIndex;
  // Counter to generate unique tip IDs.
  uint256 private nextTipId;

  // --- Events ---

  event TipDeposited(
    address indexed tipper,
    uint256 indexed tipId,
    uint256 amount,
    uint256 lockedUntil
  );
  event TipWithdrawn(address indexed withdrawer, uint256 amount);

  // --- Functions ---

  constructor(address _withdrawer, uint256 _withdrawalDelay) {
    withdrawer = _withdrawer;
    withdrawalDelay = _withdrawalDelay;
  }

  /**
   * @notice Deposits a tip into the jar. The tip will be locked for the `withdrawalDelay`.
   */
  function depositTip() external payable returns (uint256) {
    if (msg.value <= 0) revert TimedTipJar__TipAmountMustBeMoreThanZero();

    uint256 tipId = nextTipId;
    tips[tipId] = Tip(msg.sender, msg.value, block.timestamp + withdrawalDelay);
    tipIds.push(tipId);
    tipIdToIndex[tipId] = tipIds.length - 1;

    emit TipDeposited(msg.sender, tipId, msg.value, tips[tipId].lockedUntil);

    // Increment the counter for the next tip.
    // Using unchecked for gas savings as overflow is virtually impossible.
    unchecked {
      nextTipId++;
    }

    return tipId;
  }

  /**
   * @notice Withdraws a batch of tips that are past their lock time.
   * @param _maxTipsToProcess The maximum number of tips to check in this transaction.
   * This prevents running out of gas if the tip jar has many entries.
   * The withdrawer should call this function repeatedly if necessary to withdraw all available tips.
   */
  function withdrawTips(uint256 _maxTipsToProcess) external {
    if (msg.sender != withdrawer) {
      revert TimedTipJar__OnlyWithdrawerCanWithdraw();
    }

    uint256 tipWithdrawable = 0;
    uint256 tipCount = tipIds.length;
    uint256 tipsToCheck =
      tipCount < _maxTipsToProcess ? tipCount : _maxTipsToProcess;

    uint256[] memory tipIdsToRemove = new uint256[](tipsToCheck);
    uint256 removeCount = 0;

    // Iterate from the end of the array for `tipsToCheck` items.
    // This is efficient because the user can repeatedly call this to process the whole array
    // from end to start without reprocessing items.
    for (uint256 i = 0; i < tipsToCheck; i++) {
      uint256 index = tipCount - 1 - i;
      uint256 tipId = tipIds[index];

      if (tips[tipId].lockedUntil <= block.timestamp) {
        tipWithdrawable += tips[tipId].ethAmount;
        tipIdsToRemove[removeCount] = tipId;
        removeCount++;
      }
    }

    if (tipWithdrawable <= 0) {
      revert TimedTipJar__WithdrawableTipMustBeMoreThanZero();
    }

    // Remove the identified tips using the gas-efficient swap-and-pop method.
    for (uint256 i = 0; i < removeCount; i++) {
      _removeTip(tipIdsToRemove[i]);
    }

    (bool success,) = withdrawer.call{value: tipWithdrawable}("");
    if (!success) {
      revert TimedTipJar__TipsWithdrawalFailed();
    }
    emit TipWithdrawn(withdrawer, tipWithdrawable);
  }

  function _removeTip(uint256 _tipId) private {
    uint256 indexToRemove = tipIdToIndex[_tipId];
    uint256 lastTipId = tipIds[tipIds.length - 1];
    tipIds[indexToRemove] = lastTipId;
    tipIdToIndex[lastTipId] = indexToRemove;
    tipIds.pop();
    delete tipIdToIndex[_tipId];
    delete tips[_tipId];
  }

  // --- View Functions ---

  function getTipCount() external view returns (uint256) {
    return tipIds.length;
  }

  function getTipIdAtIndex(uint256 _index) external view returns (uint256) {
    return tipIds[_index];
  }

  function getTip(uint256 _tipId) external view returns (Tip memory) {
    return tips[_tipId];
  }
}
