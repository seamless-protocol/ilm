// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { PointsEmissionsStorage } from "./storage/PointsEmissionsStorage.sol";

/// @title PointsEmissions
/// @notice Contract for rewarding points based on emission per second and proportional share of each account
abstract contract PointsEmissions is Initializable {

  function __PointsEmissions_init(
    IERC20 _rewardToken,
    uint256 _emissionsPerSecond,
    uint256 _sharesUnit
  ) internal initializer {
      PointsEmissionsStorage.Layout storage $ = PointsEmissionsStorage.layout();
      $.rewardToken = _rewardToken;
      $.emissionsPerSecond = _emissionsPerSecond;
      $.sharesUnit = _sharesUnit;
      $.totalShares = 0;
  }

  /// @notice updates the emissions per share index based on the emissions per second and time passed from last update
  function _updateEmissionsIndex() internal {
    PointsEmissionsStorage.Layout storage $ = PointsEmissionsStorage.layout();
    if ($.totalShares == 0) {
      return;
    }
    uint256 timePassed = block.timestamp - $.lastUpdatedEmissionsIndexTimestamp;
    if (timePassed == 0) {
      return;
    }
    uint256 totalEmissions = timePassed * $.emissionsPerSecond;
    uint256 totalEmissionsPerShare = Math.mulDiv(totalEmissions, $.sharesUnit, $.totalShares);

    $.emissionsPerShareIndex += totalEmissionsPerShare;
    $.lastUpdatedEmissionsIndexTimestamp = block.timestamp;
  }

  /// @notice updates the unclaimed reward for account based on change in the emission index
  /// @dev _updateEmissionsIndex must be called at the start of this function
  /// @param account address of the account for which to update reward
  function _updateReward(address account) internal {
    _updateEmissionsIndex();
    PointsEmissionsStorage.Layout storage $ = PointsEmissionsStorage.layout();
    PointsEmissionsStorage.AccountData storage accountData = $.accountData[account];
    if (accountData.shares == 0) {
      return;
    }

    uint256 emissionsIndexDiff = $.emissionsPerShareIndex - accountData.lastUpdatedEmissionsIndex;
    if (emissionsIndexDiff == 0) {
      return;
    }
    uint256 earnedPoints = Math.mulDiv(emissionsIndexDiff, accountData.shares, $.sharesUnit);

    accountData.unclaimedReward += earnedPoints; 
    accountData.lastUpdatedEmissionsIndex = $.emissionsPerShareIndex;
  }

  /// @notice adds shares to the account
  /// @dev _updateReward must be called before changing the share amount
  /// @param account address for which to add shares
  /// @param shares amount of shares to add
  function _addShares(address account, uint256 shares) internal {
    _updateReward(account);
    PointsEmissionsStorage.Layout storage $ = PointsEmissionsStorage.layout();
    PointsEmissionsStorage.AccountData storage accountData = $.accountData[account];
    $.totalShares += shares;
    accountData.shares += shares;
  }

  /// @notice removes shares from the account
  /// @dev _updateReward must be called before changing the share amount
  /// @param account address for which to remove shares
  /// @param shares amount of shares to remove
  function _removeShares(address account, uint256 shares) internal {
    _updateReward(account);
    PointsEmissionsStorage.Layout storage $ = PointsEmissionsStorage.layout();
    PointsEmissionsStorage.AccountData storage accountData = $.accountData[account];
    $.totalShares -= shares;
    accountData.shares -= shares;
    _claimReward(account);
  }

  /// @notice claims acummulated reward for the account
  /// @param account address of account to claim reward
  function _claimReward(address account) internal {
    _updateReward(account);
    PointsEmissionsStorage.Layout storage $ = PointsEmissionsStorage.layout();
    PointsEmissionsStorage.AccountData storage accountData = $.accountData[account];
    uint256 reward = accountData.unclaimedReward;
    if (reward == 0) {
      return;
    }

    accountData.unclaimedReward = 0;

    SafeERC20.safeTransfer($.rewardToken, account, reward);
  }

  /// @notice changes emissions per second of reward token
  /// @param _emissionsPerSecond emissions of token per second
  function _setEmissionsPerSecond(uint256 _emissionsPerSecond) internal {
    PointsEmissionsStorage.layout().emissionsPerSecond = _emissionsPerSecond;
  }
}