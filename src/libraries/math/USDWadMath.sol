// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title WadUSDMath library
 * @author Seamless
 * @notice Provides functions to perform calculations with USD units and Wads
 * @dev Provides mul and div function for USD (decimal numbers with 8 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library USDWadMath {
    // HALF_WAD and HALF_USD expressed with extended notation as constant with operations are not supported in Yul assembly
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant USD = 1e8;
    uint256 internal constant HALF_USD = 0.5e8;

    uint256 internal constant USD_WAD_RATIO = 1e10;

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
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) {
                revert(0, 0)
            }

            c := div(add(mul(a, b), HALF_WAD), WAD)
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
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_USD), b))))) {
                revert(0, 0)
            }

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
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) {
                revert(0, 0)
            }

            c := div(add(mul(a, WAD), div(b, 2)), b)
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
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), USD))))) {
                revert(0, 0)
            }

            c := div(add(mul(a, USD), div(b, 2)), b)
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
            if iszero(lt(remainder, div(USD_WAD_RATIO, 2))) {
                b := add(b, 1)
            }
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

            if iszero(eq(div(b, USD_WAD_RATIO), a)) {
                revert(0, 0)
            }
        }
    }
}
