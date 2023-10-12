// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { PercentageMath } from "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { LoanState } from "../../src/types/DataTypes.sol";
import { TestConstants } from "../config/TestConstants.sol";

/// @notice Unit tests for the LoanLogic library
/// @dev testing on forked Base mainnet to be able to interact with already deployed Seamless pool
/// @dev assuming that `BASE_MAINNET_RPC_URL` is set in the `.env`
contract LoanLogicTest is Test, TestConstants {
    IPoolAddressesProvider public constant poolAddressProvider = LoanLogic.poolAddressProvider;
    IPoolDataProvider public poolDataProvider;
    IPriceOracleGetter public priceOracle;

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    IERC20 public sWETH;
    IERC20 public debtUSDbC;
    uint256 public ltvWETH;

    uint256 public WETH_price;
    uint256 public USDbC_price;
    
    function setUp() public {
        string memory mainnetRpcUrl = vm.envString(BASE_MAINNET_RPC_URL);
        uint256 mainnetFork = vm.createFork(mainnetRpcUrl);
        vm.selectFork(mainnetFork);

        poolDataProvider = IPoolDataProvider(poolAddressProvider.getPoolDataProvider());
        (, ltvWETH, , , , , , , , ) = poolDataProvider.getReserveConfigurationData(address(WETH));

        // getting reserve token addresses
        (address sWETHaddress , , ) = poolDataProvider.getReserveTokensAddresses(address(WETH));
        sWETH = IERC20(sWETHaddress);

        ( , , address debtUSDbCaddress) = poolDataProvider.getReserveTokensAddresses(address(USDbC));
        debtUSDbC = IERC20(debtUSDbCaddress);

        // getting token prices
        priceOracle = IPriceOracleGetter(poolAddressProvider.getPriceOracle());
        WETH_price = priceOracle.getAssetPrice(address(WETH));
        USDbC_price = priceOracle.getAssetPrice(address(USDbC));

        deal(address(WETH), address(this), 100 ether);

        // approve tokens for pool to use on supplying and repaying
        WETH.approve(poolAddressProvider.getPool(), 100 ether);
        USDbC.approve(poolAddressProvider.getPool(), 1000000 * ONE_USDbC);
    }

    function test_Supply() public {
      uint256 wethAmountBefore = WETH.balanceOf(address(this));
      uint256 supplyAmount = 10 ether;

      LoanState memory loanState;
      loanState = LoanLogic.supply(WETH, supplyAmount);

      _validateLoanState(loanState, supplyAmount, 0);
      assertEq(WETH.balanceOf(address(this)), wethAmountBefore - supplyAmount);
      assertEq(sWETH.balanceOf(address(this)), supplyAmount);
    }

    function test_Withdraw() public {
      uint256 wethAmountBefore = WETH.balanceOf(address(this));
      uint256 supplyAmount = 10 ether;
      uint256 withdrawAmount = 5 ether;
      LoanLogic.supply(WETH, supplyAmount);

      LoanState memory loanState;
      loanState = LoanLogic.withdraw(WETH, withdrawAmount);

      _validateLoanState(loanState, supplyAmount - withdrawAmount, 0);
      assertApproxEqAbs(WETH.balanceOf(address(this)), wethAmountBefore - supplyAmount + withdrawAmount, 1 wei);
      assertApproxEqAbs(sWETH.balanceOf(address(this)), supplyAmount - withdrawAmount, 1 wei);
    }

    function test_Borrow() public {
      uint256 supplyAmount = 10 ether;
      uint256 borrowAmount = 1000 * ONE_USDbC;
      LoanLogic.supply(WETH, supplyAmount);

      LoanState memory loanState;
      loanState = LoanLogic.borrow(USDbC, borrowAmount);

      _validateLoanState(loanState, supplyAmount, borrowAmount);
      assertEq(debtUSDbC.balanceOf(address(this)), borrowAmount);
    }

    function test_Repay() public {
      uint256 supplyAmount = 10 ether;
      uint256 borrowAmount = 1000 * ONE_USDbC;
      uint256 repayAmount = 500 * ONE_USDbC;
      LoanLogic.supply(WETH, supplyAmount);
      LoanLogic.borrow(USDbC, borrowAmount);

      LoanState memory loanState;
      loanState = LoanLogic.repay(USDbC, repayAmount);

      _validateLoanState(loanState, supplyAmount, borrowAmount - repayAmount);
      assertApproxEqAbs(debtUSDbC.balanceOf(address(this)), borrowAmount - repayAmount, 1 wei);
    }

    function _validateLoanState(
      LoanState memory loanState, 
      uint256 collateralWETHAmount, 
      uint256 debtUSDbCAmount
    ) internal {
      // we should get value with same number of decimals as price
      // so we deviding by the decimals of the asset
      uint256 collateralUSD = Math.mulDiv(collateralWETHAmount, WETH_price, 1 ether);
      assertApproxEqAbs(loanState.collateral, collateralUSD, 1 wei);

      uint256 debtUSD = Math.mulDiv(debtUSDbCAmount, USDbC_price, ONE_USDbC);
      // we allow for absolute error of 1000 wei because prices have 8 decimals, 
      // while USDbC has 6 decimals, and there is a loss of precision
      assertApproxEqAbs(loanState.debt, debtUSD, 1000 wei);

      uint256 maxBorrowUSD = PercentageMath.percentMul(collateralUSD, ltvWETH);
      uint256 maxAvailableBorrow = maxBorrowUSD - debtUSD;
      assertApproxEqAbs(loanState.maxBorrowAmount, maxAvailableBorrow, 1000 wei);

      uint256 minCollateralUSD = PercentageMath.percentDiv(debtUSD, ltvWETH);
      uint256 maxAvailableWithdraw = collateralUSD - minCollateralUSD;
      assertApproxEqAbs(loanState.maxWithdrawAmount, maxAvailableWithdraw, 1000 wei);
    }
}