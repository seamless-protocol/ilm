// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { SimulationHandler } from "./SimulationHandler.sol";
import { IntegrationBase } from "./IntegrationBase.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";

/// @notice Simulates large number of deposit and withdraw transactions on the strategy through time
/// @notice and writes parameters in the json output
contract SimulationTest is IntegrationBase {
    SimulationHandler public handler;

    uint256 public cbETHApy = 4_00; // 4%

    MockAaveOracle public mockOracle;

    function setUp() public virtual override {
        super.setUp();

        uint256 numUsers = 10;
        uint256 startAmount = 100 ether;
        string memory jsonPath = "./test/integration/output/simulation.json";

        handler =
            new SimulationHandler(strategy, numUsers, startAmount, jsonPath);

        uint256 currWethPrice = IPriceOracleGetter(
            poolAddressesProvider.getPriceOracle()
        ).getAssetPrice(address(WETH));
        uint256 currCbETHPrice = IPriceOracleGetter(
            poolAddressesProvider.getPriceOracle()
        ).getAssetPrice(address(CbETH));

        // deploy MockAaveOracle to the address of already existing priceOracle
        MockAaveOracle mockAaveOracle = new MockAaveOracle();
        bytes memory mockOracleCode = address(mockAaveOracle).code;
        vm.etch(poolAddressesProvider.getPriceOracle(), mockOracleCode);
        mockOracle = MockAaveOracle(poolAddressesProvider.getPriceOracle());

        _changePrice(WETH, currWethPrice);
        _changePrice(CbETH, currCbETHPrice);
        _changePrice(wrappedCbETH, currCbETHPrice);
    }

    /// @notice Simulates large number of deposit and withdraw transactions on the strategy through time
    /// @notice and writes parameters in the json output
    function test_e2eSimulation() public {
        uint256 actions = 100;
        uint256 seed = 1;

        for (uint256 i = 0; i < actions; i++) {
            seed = _nextSeed(seed);

            uint256 action = bound(seed, 0, 1);

            if (action == 0) {
                handler.deposit(seed);
            }

            if (action == 1) {
                handler.redeem(seed);
            }

            _passTimeAndUpdatePrices(seed);
        }

        handler.saveJson();
    }

    /// @dev used to generate the next random seed
    /// @param seed previous random seed
    function _nextSeed(uint256 seed) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed)));
    }

    /// @dev passes time on the pool, and updates prices of WETH/CbETH
    /// @dev price of WETH is changed randomly up to +-2%
    /// @dev price of CbETH follows defined APY in regards to ETH price
    /// @param seed random seed
    function _passTimeAndUpdatePrices(uint256 seed) internal {
        uint256 duration = 7 days;
        skip(duration);

        uint256 ethPrice = mockOracle.getAssetPrice(address(WETH));
        uint256 cbETHPrice = mockOracle.getAssetPrice(address(CbETH));
        uint256 percentChange = bound(seed, 1, 2_00); // from 0.01% to 2%
        uint256 ethPriceChange =
            PercentageMath.percentMul(ethPrice, percentChange);
        uint256 cbETHPriceChange =
            PercentageMath.percentMul(cbETHPrice, percentChange);
        if (seed % 2 == 0) {
            ethPrice += ethPriceChange;
            cbETHPrice += cbETHPriceChange;
        } else {
            ethPrice -= ethPriceChange;
            cbETHPrice -= cbETHPriceChange;
        }

        uint256 cbETHyeild = (
            PercentageMath.percentMul(cbETHPrice, cbETHApy) * duration
        ) / 365 days;
        cbETHPrice += cbETHyeild;

        _changePrice(WETH, ethPrice);
        _changePrice(CbETH, cbETHPrice);
        _changePrice(wrappedCbETH, cbETHPrice);
    }

    /// @dev changes price for the given token
    /// @param token token which price is changed
    /// @param price new price
    function _changePrice(IERC20 token, uint256 price) internal {
        mockOracle.setAssetPrice(address(token), price);
    }
}
