// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { SwapperMock } from "../mock/SwapperMock.sol";
import { CollateralRatio, LendingPool, LoanState, StrategyAssets } from "../../src/types/DataTypes.sol";

/// @title RebalanceLogicContext contract
/// @dev Setup for the context in which the RebalanceLogic library is tested.
abstract contract RebalanceLogicContext is BaseForkTest {
    /// contracts needed for setting up and testing RebalanceLogic
    IPoolAddressesProvider public constant poolAddressProvider = IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);
    IPriceOracleGetter public oracle;
    IPoolDataProvider public poolDataProvider;
    LendingPool lendingPool;
    StrategyAssets public assets;
    SwapperMock public swapper;
    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);

     /// values required for setting up and testing RebalanceLogic
     uint256 public WETH_price;
     uint256 public USDbC_price;
     uint256 public ltvWETH;

    uint256 internal constant BASIS = 1e8;

    uint256 internal constant MINT_AMOUNT = 1 ether;

    uint256 targetCR;
    
    /// @dev sets up auxiliary contracts and context for RebalanceLogic tests
    function setUp() public virtual {
        lendingPool = LendingPool({
             pool: IPool(poolAddressProvider.getPool()),
             // variable interest rate mode is 2
             interestRateMode: 2
         });

        assets.collateral = WETH;
        assets.debt = USDbC;

        poolDataProvider = IPoolDataProvider(poolAddressProvider.getPoolDataProvider());
        (, ltvWETH, , , , , , , , ) = poolDataProvider.getReserveConfigurationData(address(WETH));

        // getting token prices
        oracle = IPriceOracleGetter(poolAddressProvider.getPriceOracle());
        WETH_price = oracle.getAssetPrice(address(WETH));
        USDbC_price = oracle.getAssetPrice(address(USDbC));

        // deploy mock swapper instance
        swapper = new SwapperMock(address(assets.collateral), address(assets.debt), address(oracle));

        assert(
             address(swapper.borrowAsset()) == address(USDbC)
        );
        assert(
             address(swapper.collateralAsset()) == address(WETH)
        );

        // fake minting some tokens to start with
        deal(address(WETH), address(this), MINT_AMOUNT);
        deal(address(USDbC), address(this), MINT_AMOUNT);

        // approve tokens for pool to use on supplying and repaying
        WETH.approve(poolAddressProvider.getPool(), MINT_AMOUNT);
        USDbC.approve(poolAddressProvider.getPool(), MINT_AMOUNT);

        deal(address(WETH), address(swapper), MINT_AMOUNT);
        deal(address(USDbC), address(swapper), MINT_AMOUNT);

        assert(USDbC.balanceOf(address(swapper)) == MINT_AMOUNT);
        assert(WETH.balanceOf(address(swapper)) == MINT_AMOUNT);
        
        // 3x leverage using collateral ratio at 1.5
        targetCR = 1.5e8;
    }
}