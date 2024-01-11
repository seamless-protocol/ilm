// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { SwapAdapterBase } from "../../src/swap/adapter/SwapAdapterBase.sol";

/// @title SwapAdapterBaseHarness
/// @dev exposes SwapAdapterBase internal functions for testing
contract SwapAdapterBaseHarness is SwapAdapterBase {
    /// @dev exposes the _setSwapper internal function
    function exposed_setSwapper(address swapper) external {
        _setSwapper(swapper);
    }

    /// @dev exposes the _getSwapper internal function
    function exposed_getSwapper() external view returns (address swapper) {
        return _getSwapper();
    }

    /// @dev unimplemented in harness contract
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external returns (uint256 toAmount) {
        // unimplemented
    }

    /// @dev unimplemented in harness contract
    function setSwapper(address swapper) external { }

    /// @dev unimplemented in harness contract
    function getSwapper() external view returns (address swapper) { }
}
