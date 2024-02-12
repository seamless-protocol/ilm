
pragma solidity ^0.8.21;

import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import {LoopStrategy} from "../../src/LoopStrategy.sol";

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

}