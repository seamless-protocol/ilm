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
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
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

    // maximum allowed absolute error on USD amounts. 
    // It's set to 1000 wei because of difference in Chainlink oracle decimals and USDbC decimals
    uint256 public USD_DELTA = 1000 wei;

    /// @dev set up testing on the fork of the base mainnet
    /// @dev and get all needed parameters from already deployed pool
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

        // fake minting some tokens to start with
        deal(address(WETH), address(this), 100 ether);

        // approve tokens for pool to use on supplying and repaying
        WETH.approve(poolAddressProvider.getPool(), 100 ether);
        USDbC.approve(poolAddressProvider.getPool(), 1000000 * ONE_USDbC);
    }

    /// @dev test confirming that laon state is valid after withdrawing 
    /// @dev and that we get correct amount of WETH and sWETH tokens
    function test_supply() public {
      uint256 wethAmountBefore = WETH.balanceOf(address(this));
      uint256 supplyAmount = 10 ether;

      LoanState memory loanState;
      loanState = LoanLogic.supply(WETH, supplyAmount);

      _validateLoanState(loanState, supplyAmount, 0);
      assertEq(WETH.balanceOf(address(this)), wethAmountBefore - supplyAmount);
      assertEq(sWETH.balanceOf(address(this)), supplyAmount);
    }

    /// @dev test confirming that laon state is valid after withdrawing 
    /// @dev and that we get correct amount of WETH and sWETH tokens
    function test_withdraw() public {
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

    /// @dev test confirming that laon state is valid after borrowing 
    /// @dev and that we get correct amount of debtUSDbC token
    function test_borrow() public {
      uint256 supplyAmount = 10 ether;
      uint256 borrowAmount = 1000 * ONE_USDbC;
      LoanLogic.supply(WETH, supplyAmount);

      LoanState memory loanState;
      loanState = LoanLogic.borrow(USDbC, borrowAmount);

      _validateLoanState(loanState, supplyAmount, borrowAmount);
      assertEq(debtUSDbC.balanceOf(address(this)), borrowAmount);
    }

    /// @dev test confirming that laon state is valid after repaying 
    /// @dev and that we get correct amount of debtUSDbC token
    function test_repay() public {
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

    /// @dev test confirming that we can borrow `maxBorrowAmount` returned from loan state
    function test_borrow_maxBorrow() public {
      uint256 supplyAmount = 10 ether;
      LoanState memory loanState;
      loanState = LoanLogic.supply(WETH, supplyAmount);

      // converting loanState.maxBorrowAmount (USD) amount to the USDbC asset amount
      // substrcting USD_DELTA because of precision issues
      uint256 borrowAmount = Math.mulDiv(loanState.maxBorrowAmount - USD_DELTA, ONE_USDbC, USDbC_price);

      loanState = LoanLogic.borrow(USDbC, borrowAmount);
      assertApproxEqAbs(loanState.maxBorrowAmount, 0, 2*USD_DELTA);

      _validateLoanState(loanState, supplyAmount, borrowAmount);
      assertApproxEqAbs(debtUSDbC.balanceOf(address(this)), borrowAmount, 1 wei);
    }

    /// @dev test reverting when borrow 0.1% above `maxBorrowAmount` returned from loan state
    function test_borrow_maxBorrow_revertAboveMax() public {
      uint256 supplyAmount = 10 ether;
      LoanState memory loanState;
      loanState = LoanLogic.supply(WETH, supplyAmount);

      uint256 borrowAmount = Math.mulDiv(loanState.maxBorrowAmount, ONE_USDbC, USDbC_price);
      // calculating 0.1% above max value
      uint256 borrowAmountAboveMax = borrowAmount + PercentageMath.percentMul(borrowAmount, 10);

      vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
      LoanLogic.borrow(USDbC, borrowAmountAboveMax);
    }

    /// @dev test confirming that we can withdraw `maxWithdrawAmount` returned from loan state
    function test_withdraw_maxWithdraw() public {
      uint256 wethAmountBefore = WETH.balanceOf(address(this));
      uint256 supplyAmount = 10 ether;
      uint256 borrowAmount = 1000 * ONE_USDbC;
      LoanLogic.supply(WETH, supplyAmount);
      LoanState memory loanState;
      loanState = LoanLogic.borrow(USDbC, borrowAmount);
      
      // converting loanState.maxWithdrawAmount (USD) amount to the WETH asset amount
      // substrcting USD_DELTA because of precision issues
      uint256 withdrawAmount = Math.mulDiv(loanState.maxWithdrawAmount - USD_DELTA, 1 ether, WETH_price);
      loanState = LoanLogic.withdraw(WETH, withdrawAmount);
      assertApproxEqAbs(loanState.maxBorrowAmount, 0, USD_DELTA);

      _validateLoanState(loanState, supplyAmount - withdrawAmount, borrowAmount);
      assertApproxEqAbs(WETH.balanceOf(address(this)), wethAmountBefore - supplyAmount + withdrawAmount, 1 wei);
      assertApproxEqAbs(sWETH.balanceOf(address(this)), supplyAmount - withdrawAmount, 1 wei);
    }

    /// @dev test reverting when withdraw 0.1% above `maxWithdrawAmount` returned from loan state
    function test_withdraw_maxWithdraw_revertAboveMax() public {
      uint256 supplyAmount = 10 ether;
      uint256 borrowAmount = 1000 * ONE_USDbC;
      LoanLogic.supply(WETH, supplyAmount);
      LoanState memory loanState;
      loanState = LoanLogic.borrow(USDbC, borrowAmount);
      
      uint256 withdrawAmount = Math.mulDiv(loanState.maxWithdrawAmount, 1 ether, WETH_price);
      // calculating 0.1% above max value
      uint256 withdrawAmountAboveMax = withdrawAmount + PercentageMath.percentMul(withdrawAmount, 10);

      vm.expectRevert();
      LoanLogic.withdraw(WETH, withdrawAmountAboveMax);
    }

    /// @dev validates if the returned LoanState values correspond for the given asset amounts
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
      assertApproxEqAbs(loanState.debt, debtUSD, USD_DELTA);

      uint256 maxBorrowUSD = PercentageMath.percentMul(collateralUSD, ltvWETH);
      uint256 maxAvailableBorrow = maxBorrowUSD - debtUSD;
      assertApproxEqAbs(loanState.maxBorrowAmount, maxAvailableBorrow, USD_DELTA);

      uint256 minCollateralUSD = PercentageMath.percentDiv(debtUSD, ltvWETH);
      uint256 maxAvailableWithdraw = collateralUSD - minCollateralUSD;
      assertApproxEqAbs(loanState.maxWithdrawAmount, maxAvailableWithdraw, USD_DELTA);
    }
}