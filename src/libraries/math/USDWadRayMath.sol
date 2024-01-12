// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

/**
 * @title WadRayMath library
 * @author Aave
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision), and USDs (decimal numbers with 8 digits of precisions)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 * @dev USD-related functionality added by Seamless
 */
library USDWadRayMath {
    // HALF_WAD and HALF_RAY expressed with extended notation as constant with operations are not supported in Yul assembly
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    uint256 internal constant USD = 1e8;
    uint256 internal constant HALF_USD = 0.5e8;

    uint256 internal constant USD_WAD_RATIO = 1e10;
    uint256 internal constant WAD_RAY_RATIO = 1e9;

    /**
     * @dev Multiplies two wad, rounding half up to the nearest wad
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Wad
     * @param b Wad
     * @return c = a*b, in wad
     */
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
        assembly {
            if iszero(
                or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))
            ) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_WAD), WAD)
        }
    }

    /// @dev Divides two USD, rounding half up to the nearest USD
    /// @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
    /// @param a USD
    /// @param b USD
    /// @return c = a/b, in USD
    function usdDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / USD
        assembly {
            if or(
                iszero(b),
                iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), USD))))
            ) { revert(0, 0) }

            c := div(add(mul(a, USD), div(b, 2)), b)
        }
    }

    /// @dev Multiplies two USD, rounding half up to the nearest USD
    /// @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
    /// @param a USD
    /// @param b USD
    /// @return c = a*b, in USD
    function usdMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_USD) / b
        assembly {
            if iszero(
                or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_USD), b))))
            ) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_USD), USD)
        }
    }

    /**
     * @dev Divides two wad, rounding half up to the nearest wad
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Wad
     * @param b Wad
     * @return c = a/b, in wad
     */
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / WAD
        assembly {
            if or(
                iszero(b),
                iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))
            ) { revert(0, 0) }

            c := div(add(mul(a, WAD), div(b, 2)), b)
        }
    }

    /**
     * @notice Multiplies two ray, rounding half up to the nearest ray
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Ray
     * @param b Ray
     * @return c = a raymul b
     */
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
        assembly {
            if iszero(
                or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))
            ) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    /**
     * @notice Divides two ray, rounding half up to the nearest ray
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Ray
     * @param b Ray
     * @return c = a raydiv b
     */
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / RAY
        assembly {
            if or(
                iszero(b),
                iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))
            ) { revert(0, 0) }

            c := div(add(mul(a, RAY), div(b, 2)), b)
        }
    }

    /**
     * @dev Casts ray down to wad
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Ray
     * @return b = a converted to wad, rounded half up to the nearest wad
     */
    function rayToWad(uint256 a) internal pure returns (uint256 b) {
        assembly {
            b := div(a, WAD_RAY_RATIO)
            let remainder := mod(a, WAD_RAY_RATIO)
            if iszero(lt(remainder, div(WAD_RAY_RATIO, 2))) { b := add(b, 1) }
        }
    }

    /**
     * @dev Converts wad up to ray
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Wad
     * @return b = a converted in ray
     */
    function wadToRay(uint256 a) internal pure returns (uint256 b) {
        // to avoid overflow, b/WAD_RAY_RATIO == a
        assembly {
            b := mul(a, WAD_RAY_RATIO)

            if iszero(eq(div(b, WAD_RAY_RATIO), a)) { revert(0, 0) }
        }
    }

    /// @dev Casts wad down to USD
    /// @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
    /// @param a Wad
    /// @return b = a converted to USD, rounded half up to the nearest USD
    function wadToUSD(uint256 a) internal pure returns (uint256 b) {
        assembly {
            b := div(a, USD_WAD_RATIO)
            let remainder := mod(a, USD_WAD_RATIO)
            if iszero(lt(remainder, div(USD_WAD_RATIO, 2))) { b := add(b, 1) }
        }
    }

    /// @dev Converts USD up to Wad
    /// @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
    /// @param a USD
    /// @return b = a converted in wad
    function usdToWad(uint256 a) internal pure returns (uint256 b) {
        // to avoid overflow, b/USD_WAD_RATIO == a
        assembly {
            b := mul(a, USD_WAD_RATIO)

            if iszero(eq(div(b, USD_WAD_RATIO), a)) { revert(0, 0) }
        }
    }
}
