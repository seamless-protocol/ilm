// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { CollateralRatio, StrategyAssets, LendingPool } from "../types/DataTypes.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol"; 
import { IPriceOracleGetter } from "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";

library LoopStrategyStorage {
    /// @dev struct containing all state for the LoopStrategy contract
    struct Layout {
        /// @dev struct encapsulating collateral and borrow asset addresses
        StrategyAssets strategyAssets;
        /// @dev struct encapsulating min/max bounds and target values for the collateral ratio
        /// TODO: decide on whether to be 1e8 or 1e18 or 1e27
        CollateralRatio collateralRatioTargets;
        /// @dev pool address provider for the Seamles Protocol lending pools
        IPoolAddressesProvider poolAddressProvider;
        /// @dev struct encapsulating address of the lending pool and configuration (interest rate mode)
        LendingPool lendingPool;
        /// @dev price oracle address
        IPriceOracleGetter oracle;
        /// @dev swapper address
        ISwapper swapper;

        /// @dev error margin on specific target collateral ratio passed in function calls
        uint256 ratioMargin;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('seamless.contracts.storage.LoopStrategy');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
