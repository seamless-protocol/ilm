// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { Commands } from "../../vendor/aerodrome/Commands.sol";
import { IUniversalAerodromeAdapter } from
    "../../interfaces/IUniversalAerodromeAdapter.sol";
import { IUniversalRouter } from "../../vendor/aerodrome/IUniversalRouter.sol";
import { SwapAdapterBase } from "./SwapAdapterBase.sol";

contract UniversalAerodromeAdapter is
    SwapAdapterBase,
    IUniversalAerodromeAdapter
{
    address public constant UNIVERSAL_ROUTER =
        0x6Cb442acF35158D5eDa88fe602221b67B400Be3E;

    mapping(IERC20 from => mapping(IERC20 to => bytes path)) swapPaths;

    constructor(address initialOwner) Ownable(initialOwner) { }

    function executeSwap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external onlySwapper returns (uint256 toAmount) {
        return _executeSwap(from, to, fromAmount, beneficiary);
    }

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

    function setSwapper(address swapper) external onlyOwner {
        _setSwapper(swapper);
    }

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

    function _encodeSlipstreamExactInSwap(
        address beneficiary,
        IERC20 from,
        IERC20 to,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal view returns (bytes memory swapData) {
        swapData = abi.encode(
            beneficiary, amountIn, amountOutMin, swapPaths[from][to], true
        );
    }
}
