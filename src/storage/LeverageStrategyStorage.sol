// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import {CollateralRatio, StrategyAssets} from "../types/DataTypes.sol";

library LeverageStrategyStorage {
    /// @dev struct containing all state for the LeverageStrategy contract
    struct Layout {
        /// @dev struct encapsulating collateral and borrow asset addresses
        StrategyAssets strategyAssets;
        /// @dev struct encapsulating min/max bounds and target values for the collateral ratio
        /// TODO: decide on whether to be 1e8 or 1e18 or 1e27
        CollateralRatio collateralRatio;
        /// @dev error margin on specific target collateral ratio passed in function calls
        uint256 ratioMargin;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("seamless.contracts.storage.LeverageStrategy");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
