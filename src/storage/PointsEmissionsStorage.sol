// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

library PointsEmissionsStorage {
    /// @dev struct containing state for the one account address
    struct AccountData {
      /// @dev amount of account's shares used for calculating proportion of the reward
      uint256 shares;
      /// @dev amount of unclaimed reward
      uint256 unclaimedReward;
      /// @dev emissions index value on last update of shares
      uint256 lastUpdatedEmissionsIndex;
    }

    /// @dev struct containing all state for the PointsEmissions contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.PointsEmissions
    struct Layout {
      /// @dev token which is rewarded
      IERC20 rewardToken;
      /// @dev 1 unit of share (i.e. 10 ** decimals)
      uint256 sharesUnit;
      /// @dev total amount of shares
      uint256 totalShares;
      /// @dev amount of reward token which is emitted per second for the whole pool
      uint256 emissionsPerSecond;
      /// @dev total amount of emissions at this point per share
      uint256 emissionsPerShareIndex;
      /// @dev timestamp of the last update of emission index
      uint256 lastUpdatedEmissionsIndexTimestamp;
      /// @dev map contains state for the given account address
      mapping(address => AccountData) accountData;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.PointsEmissions")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT = 0x635EC74915F841C70926CA45A7BEE405709B5D24BCD3AFAAAD5FBEBE6CE81200;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}