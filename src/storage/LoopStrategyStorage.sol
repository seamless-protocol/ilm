// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import {
    CollateralRatio,
    StrategyAssets,
    LendingPool
} from "../types/DataTypes.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";

library LoopStrategyStorage {
    /// @dev struct containing all state for the LoopStrategy contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LoopStrategy
    struct Layout {
        /// @dev struct encapsulating collateral and borrow asset addresses
        StrategyAssets assets;
        /// @dev struct encapsulating min/max bounds and target values for the collateral ratio
        /// TODO: decide on whether to be 1e8 or 1e18 or 1e27
        CollateralRatio collateralRatioTargets;
        /// @dev error margin on specific target collateral ratio passed in function calls
        uint256 ratioMargin;
        /// @dev acceptable error margin on usd values - a value from 0 - ONE_USD
        uint256 usdMargin;
        /// @dev pool address provider for the Seamles Protocol lending pools
        IPoolAddressesProvider poolAddressProvider;
        /// @dev struct encapsulating address of the lending pool and configuration (interest rate mode)
        LendingPool lendingPool;
        /// @dev price oracle address
        IPriceOracleGetter oracle;
        /// @dev swapper address
        ISwapper swapper;
        /// @dev maximum amount of loop iterations when rebalancing
        uint16 maxIterations;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LoopStrategy")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT =
        0x324C4071AA3926AF75895CE4C01A62A23C8476ED82CD28BA23ABB8C0F6634B00;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
