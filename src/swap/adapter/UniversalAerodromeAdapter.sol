// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { Commands } from "../../vendor/aerodrome/Commands.sol";
import { IUniversalRouter } from "../../vendor/aerodrome/IUniversalRouter.sol";
import { IUniversalAerodromeAdapter } from
    "../../interfaces/IUniversalAerodromeAdapter.sol";
import { ISwapAdapter } from "../../interfaces/ISwapAdapter.sol";
import { SwapAdapterBase } from "./SwapAdapterBase.sol";

/// @title AerodromeAdapter
/// @notice Adapter contract for executing swaps on aerodrome
contract UniversalAerodromeAdapter is
    SwapAdapterBase,
    IUniversalAerodromeAdapter
{
    address public constant UNIVERSAL_ROUTER =
        0x6Cb442acF35158D5eDa88fe602221b67B400Be3E;

    mapping(IERC20 from => mapping(IERC20 to => bytes path)) public swapPaths;

    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @inheritdoc ISwapAdapter
    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external onlySwapper returns (uint256 toAmount) {
        return _executeSwap(from, to, fromAmount, beneficiary);
    }

    /// @notice swaps a given amount of a token to another token, sending the final amount to the beneficiary
    /// @dev overridden internal _executeSwap function from SwapAdapterBase contract
    /// @param from address of token to swap from
    /// @param to address of token to swap to
    /// @param fromAmount amount of from token to swap
    /// @param beneficiary receiver of final to token amount
    /// @return toAmount amount of to token returned from swapping
    function _executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) internal override returns (uint256 toAmount) {
        from.transferFrom(msg.sender, address(this), fromAmount);

        from.approve(UNIVERSAL_ROUTER, fromAmount);

        bytes[] memory inputs = new bytes[](1);

        inputs[0] =
            _encodeSlipstreamExactInSwap(beneficiary, from, to, fromAmount, 0);

        uint256 oldBalance = to.balanceOf(beneficiary);

        IUniversalRouter(UNIVERSAL_ROUTER).execute(
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN))),
            inputs,
            block.timestamp
        );

        toAmount = to.balanceOf(beneficiary) - oldBalance;
    }

    /// @inheritdoc ISwapAdapter
    function setSwapper(address swapper) external onlyOwner {
        _setSwapper(swapper);
    }

    /// @inheritdoc IUniversalAerodromeAdapter
    function setPath(IERC20 from, IERC20 to, int24 tickSpacing)
        external
        onlyOwner
    {
        bytes memory path =
            abi.encodePacked(address(from), tickSpacing, address(to));

        swapPaths[from][to] = path;
        swapPaths[to][from] = path;

        emit PathSet(from, to, path);
    }

    /// @notice encodes the swapData needed for a Slpistream swap execution
    /// @param beneficiary address receiving the amount of tokens received after the swap
    /// @param from token being swapped
    /// @param to token being received
    /// @param amountIn amount of from token being swapped
    /// @param amountOutMin minimum amount to receive of to token
    /// @return swapData encoded swapData as bytes
    function _encodeSlipstreamExactInSwap(
        address beneficiary,
        IERC20 from,
        IERC20 to,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal view returns (bytes memory swapData) {
        // `true` sets `payerIsUser` in execution
        swapData = abi.encode(
            beneficiary, amountIn, amountOutMin, swapPaths[from][to], true
        );
    }
}
