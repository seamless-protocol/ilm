// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { ISwapper, Swapper } from "../../src/swap/Swapper.sol";
import { SimulationHandler } from "./SimulationHandler.sol";
import { IntegrationBase } from "./IntegrationBase.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { CollateralRatio } from "../../src/types/DataTypes.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";

/// @notice Simulates large number of deposit and withdraw transactions on the strategy through time
/// @notice and writes parameters in the json output
contract SimulationTest is IntegrationBase {
    SimulationHandler public handler;

    string public constant JSON_PATH =
        "./test/integration/output/simulation.json";

    uint256 public constant underlyingTokenApy = 3_50;
    uint256 public constant NUM_USERS = 50;
    uint256 public constant NUM_ACTIONS = 1000;
    uint256 public constant MIN_DEPOSIT = 0.1 ether;
    uint256 public constant MAX_DEPOSIT = 1 ether;
    uint256 public constant START_AMOUNT_PER_USER = 100 ether;

    uint256 public constant daysBetweenActions = 3;

    uint256 public constant TARGET_LEV = 3_000; // 3.000x

    CollateralRatio public collateralRatioTargets = CollateralRatio({
        target: USDWadRayMath.usdDiv(TARGET_LEV, TARGET_LEV - 1000),
        minForRebalance: USDWadRayMath.usdDiv(
            TARGET_LEV + 10, TARGET_LEV - 1000 + 10
            ),
        maxForRebalance: USDWadRayMath.usdDiv(
            TARGET_LEV - 10, TARGET_LEV - 1000 - 10
            ),
        maxForDepositRebalance: USDWadRayMath.usdDiv(TARGET_LEV, TARGET_LEV - 1000),
        minForWithdrawRebalance: USDWadRayMath.usdDiv(TARGET_LEV, TARGET_LEV - 1000)
    });

    uint256 public constant BORROW_RATE = 0.015 * 1e27; // 1.5%

    uint256 public constant DEX_FEE = 500000; // 0.5%

    MockAaveOracle public mockOracle;

    function setUp() public virtual override {
        super.setUp();

        _deployLoopStrategyWithMockSwapper();

        handler = new SimulationHandler(
            strategy,
            NUM_USERS,
            START_AMOUNT_PER_USER,
            MIN_DEPOSIT,
            MAX_DEPOSIT,
            JSON_PATH
        );

        uint256 currWethPrice = IPriceOracleGetter(
            poolAddressesProvider.getPriceOracle()
        ).getAssetPrice(address(WETH));
        uint256 currUnderlyingTokenPrice = IPriceOracleGetter(
            poolAddressesProvider.getPriceOracle()
        ).getAssetPrice(address(underlyingToken));

        // deploy MockAaveOracle to the address of already existing priceOracle
        MockAaveOracle mockAaveOracle = new MockAaveOracle();
        bytes memory mockOracleCode = address(mockAaveOracle).code;
        vm.etch(poolAddressesProvider.getPriceOracle(), mockOracleCode);
        mockOracle = MockAaveOracle(poolAddressesProvider.getPriceOracle());

        _changePrice(WETH, currWethPrice);
        _changePrice(underlyingToken, currUnderlyingTokenPrice);
        _changePrice(wrappedToken, currUnderlyingTokenPrice);

        vm.startPrank(testDeployer.addr);
        strategy.setCollateralRatioTargets(collateralRatioTargets);
        vm.stopPrank();

        _changeBorrowInterestRate(BORROW_RATE);
    }

    /// @notice Simulates large number of deposit and withdraw transactions on the strategy through time
    /// @notice and writes parameters in the json output
    function test_e2eSimulation() public {
        uint256 seed = 1;

        for (uint256 i = 0; i < NUM_ACTIONS; i++) {
            seed = _nextSeed(seed);
            handler.nextAction(seed);

            // pass days and rebalance if needed
            for (uint256 w = 0; w < daysBetweenActions; w++) {
                _passTimeAndUpdatePrices(seed);
                handler.rebalance();
            }
        }

        handler.saveJson();
    }

    /// @dev used to generate the next random seed
    /// @param seed previous random seed
    function _nextSeed(uint256 seed) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed)));
    }

    /// @dev passes time on the pool, and updates prices of WETH/underlyingToken
    /// @dev price of WETH is changed randomly up to +-2%
    /// @dev price of underlyingToken follows defined APY in regards to ETH price
    /// @param seed random seed
    function _passTimeAndUpdatePrices(uint256 seed) internal {
        uint256 duration = 1 days;
        skip(duration);

        uint256 ethPrice = mockOracle.getAssetPrice(address(WETH));
        uint256 underlyingTokenPrice =
            mockOracle.getAssetPrice(address(underlyingToken));
        uint256 percentChange = bound(seed, 1, 2_00); // from 0.01% to 2%
        uint256 ethPriceChange =
            PercentageMath.percentMul(ethPrice, percentChange);
        uint256 underlyingTokenPriceChange =
            PercentageMath.percentMul(underlyingTokenPrice, percentChange);
        if (seed % 2 == 0) {
            ethPrice += ethPriceChange;
            underlyingTokenPrice += underlyingTokenPriceChange;
        } else {
            ethPrice -= ethPriceChange;
            underlyingTokenPrice -= underlyingTokenPriceChange;
        }

        uint256 underlyingTokenyeild = (
            PercentageMath.percentMul(underlyingTokenPrice, underlyingTokenApy)
                * duration
        ) / 365 days;
        underlyingTokenPrice += underlyingTokenyeild;

        _changePrice(WETH, ethPrice);
        _changePrice(underlyingToken, underlyingTokenPrice);
        _changePrice(wrappedToken, underlyingTokenPrice);
    }

    /// @dev changes price for the given token
    /// @param token token which price is changed
    /// @param price new price
    function _changePrice(IERC20 token, uint256 price) internal {
        mockOracle.setAssetPrice(address(token), price);
    }

    /// @dev deploys new MockSwapper contract and new LoopStrategy which is using mock swapper
    function _deployLoopStrategyWithMockSwapper() internal {
        vm.startPrank(testDeployer.addr);
        SwapperMock swapperMock = new SwapperMock(
            address(wrappedToken),
            address(WETH),
            poolAddressesProvider.getPriceOracle()
        );
        swapperMock.setOffsets(DEX_FEE, DEX_FEE);
        swapperMock.setRealOffsets(DEX_FEE, DEX_FEE);
        swapperMock.setWrapped(IERC20(wrappedToken), true);
        vm.allowCheatcodes(address(swapperMock));

        swapper = ISwapper(swapperMock);

        strategy = _deployLoopStrategy(
            wrappedToken, testDeployer.addr, swapper, config
        );

        _setupWrappedTokenRoles(
            wrappedToken, address(swapper), address(strategy)
        );

        vm.stopPrank();
    }
}
