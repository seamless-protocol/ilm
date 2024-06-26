// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @dev minimal interface for UniversalRouter for Aerodrome Slipstream
interface IUniversalAerodromeAdapter {
    /// @notice emitted when a path for a given token pair is set
    /// @param from first token of the pool
    /// @param to second token of the pool
    /// @param path path for token swap encoded as bytes
    event PathSet(IERC20 from, IERC20 to, bytes path);

    /// @notice sets the path for a given token pair, for both directions of swapping
    /// @param from token being swapped
    /// @param to token being received
    /// @param tickSpacing tick spacing value
    function setPath(IERC20 from, IERC20 to, int24 tickSpacing) external;
}
