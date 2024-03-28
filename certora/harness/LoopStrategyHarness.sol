
pragma solidity ^0.8.21;

import { USDWadRayMath } from "../munged/src/libraries/math/USDWadRayMath.sol";
import {LoopStrategy} from "../munged/src/LoopStrategy.sol";

contract LoopStrategyHarness is LoopStrategy
{
     using USDWadRayMath for uint256;

    
    // Expose usdDiv and usdMul for self checking before replacing them with CVL functions
    function usdDivMock(uint256 a, uint256 b) external pure returns (uint256 c) {
        c = a.usdDiv(b);
    }

    function usdMulMock(uint256 a, uint256 b) external pure returns (uint256 c) {
        c = a.usdMul(b);
    }
    function getERC4626Asset() external pure returns (address) {
        ERC4626Storage memory erc4626Storage = _getERC4626StoragePublic();
        return address(erc4626Storage._asset);
    }

}