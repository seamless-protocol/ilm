// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { LendingPool, LoanState } from "../../src/types/DataTypes.sol";

/// @notice Unit tests for the LoanLogic library
/// @dev testing on forked Base mainnet to be able to interact with already deployed Seamless pool
/// @dev assuming that `BASE_MAINNET_RPC_URL` is set in the `.env`
contract LoanLogicTest is BaseForkTest {
    IPoolAddressesProvider public constant poolAddressProvider =
        IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);
    IPoolDataProvider public poolDataProvider;
    IPriceOracleGetter public priceOracle;

    LendingPool lendingPool;

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    IERC20 public sWETH;
    IERC20 public debtUSDbC;
    uint256 public ltvWETH;

    uint256 public WETH_price;
    uint256 public USDbC_price;

    // maximum allowed absolute error on USD amounts.
    // it's set to 1000 wei because of difference in Chainlink oracle decimals and USDbC decimals
    uint256 public USD_DELTA = 1000 wei;

    /// @dev set up testing on the fork of the base mainnet
    /// @dev and get all needed parameters from already deployed pool
    function setUp() public {
        lendingPool = LendingPool({
            pool: IPool(poolAddressProvider.getPool()),
            // variable interest rate mode is 2
            interestRateMode: 2
        });

        poolDataProvider =
            IPoolDataProvider(poolAddressProvider.getPoolDataProvider());
        (, ltvWETH,,,,,,,,) =
            poolDataProvider.getReserveConfigurationData(address(WETH));

        // getting reserve token addresses
        (address sWETHaddress,,) =
            poolDataProvider.getReserveTokensAddresses(address(WETH));
        sWETH = IERC20(sWETHaddress);
        (,, address debtUSDbCaddress) =
            poolDataProvider.getReserveTokensAddresses(address(USDbC));
        debtUSDbC = IERC20(debtUSDbCaddress);

        // getting token prices
        priceOracle = IPriceOracleGetter(poolAddressProvider.getPriceOracle());
        WETH_price = priceOracle.getAssetPrice(address(WETH));
        USDbC_price = priceOracle.getAssetPrice(address(USDbC));

        // fake minting some tokens to start with
        deal(address(WETH), address(this), 100 ether);

        // approve tokens for pool to use on supplying and repaying
        WETH.approve(poolAddressProvider.getPool(), 100 ether);
        USDbC.approve(poolAddressProvider.getPool(), 1_000_000 * ONE_USDbC);
    }

    /// @dev test confirming that loan state is valid after withdrawing
    /// @dev and that we get correct amount of WETH and sWETH tokens
    function test_supply() public {
        uint256 wethAmountBefore = WETH.balanceOf(address(this));
        uint256 supplyAmount = 10 ether;

        LoanState memory loanState;
        loanState = LoanLogic.supply(lendingPool, WETH, supplyAmount);

        _validateLoanState(loanState, supplyAmount, 0);
        assertEq(WETH.balanceOf(address(this)), wethAmountBefore - supplyAmount);
        assertEq(sWETH.balanceOf(address(this)), supplyAmount);
    }

    /// @dev test confirming that loan state is valid after withdrawing
    /// @dev and that we get correct amount of WETH and sWETH tokens
    function test_withdraw() public {
        uint256 wethAmountBefore = WETH.balanceOf(address(this));
        uint256 supplyAmount = 10 ether;
        uint256 withdrawAmount = 5 ether;
        LoanLogic.supply(lendingPool, WETH, supplyAmount);

        LoanState memory loanState;
        loanState = LoanLogic.withdraw(lendingPool, WETH, withdrawAmount);

        _validateLoanState(loanState, supplyAmount - withdrawAmount, 0);
        assertApproxEqAbs(
            WETH.balanceOf(address(this)),
            wethAmountBefore - supplyAmount + withdrawAmount,
            1 wei
        );
        assertApproxEqAbs(
            sWETH.balanceOf(address(this)), supplyAmount - withdrawAmount, 1 wei
        );
    }

    /// @dev test confirming that loan state is valid after borrowing
    /// @dev and that we get correct amount of debtUSDbC token
    function test_borrow() public {
        uint256 supplyAmount = 10 ether;
        uint256 borrowAmount = 1000 * ONE_USDbC;
        LoanLogic.supply(lendingPool, WETH, supplyAmount);

        LoanState memory loanState;
        loanState = LoanLogic.borrow(lendingPool, USDbC, borrowAmount);

        _validateLoanState(loanState, supplyAmount, borrowAmount);
        assertEq(debtUSDbC.balanceOf(address(this)), borrowAmount);
    }

    /// @dev test confirming that loan state is valid after repaying
    /// @dev and that we get correct amount of debtUSDbC token
    function test_repay() public {
        uint256 supplyAmount = 10 ether;
        uint256 borrowAmount = 1000 * ONE_USDbC;
        uint256 repayAmount = 500 * ONE_USDbC;
        LoanLogic.supply(lendingPool, WETH, supplyAmount);
        LoanLogic.borrow(lendingPool, USDbC, borrowAmount);

        LoanState memory loanState;
        loanState = LoanLogic.repay(lendingPool, USDbC, repayAmount);

        _validateLoanState(loanState, supplyAmount, borrowAmount - repayAmount);
        assertApproxEqAbs(
            debtUSDbC.balanceOf(address(this)),
            borrowAmount - repayAmount,
            1 wei
        );
    }

    /// @dev test confirming that we can borrow `maxBorrowAmount` returned from loan state
    function test_borrow_maxBorrow() public {
        uint256 supplyAmount = 10 ether;
        LoanState memory loanState;
        loanState = LoanLogic.supply(lendingPool, WETH, supplyAmount);

        uint256 initialMaxBorrowUSD = loanState.maxBorrowAmount;

        // converting loanState.maxBorrowAmount (USD) amount to the USDbC asset amount
        uint256 borrowAmount =
            Math.mulDiv(loanState.maxBorrowAmount, ONE_USDbC, USDbC_price);
        loanState = LoanLogic.borrow(lendingPool, USDbC, borrowAmount);

        // getting 0.01% of initial maxBorrowUSD, because we left that as a saftey for precision issues
        uint256 maxBorrowLeft = PercentageMath.percentMul(
            initialMaxBorrowUSD, 1e4 - LoanLogic.MAX_AMOUNT_PERCENT
        );
        assertApproxEqAbs(
            loanState.maxBorrowAmount, 0, maxBorrowLeft + USD_DELTA
        );

        _validateLoanState(loanState, supplyAmount, borrowAmount);
        assertApproxEqAbs(
            debtUSDbC.balanceOf(address(this)), borrowAmount, 1 wei
        );
    }

    /// @dev test reverting when borrow 0.1% above `maxBorrowAmount` returned from loan state
    function test_borrow_revertsWhen_borrowingAboveMaxBorrow() public {
        uint256 supplyAmount = 10 ether;
        LoanState memory loanState;
        loanState = LoanLogic.supply(lendingPool, WETH, supplyAmount);

        uint256 borrowAmount =
            Math.mulDiv(loanState.maxBorrowAmount, ONE_USDbC, USDbC_price);
        // calculating 0.1% above max value
        uint256 borrowAmountAboveMax =
            borrowAmount + PercentageMath.percentMul(borrowAmount, 10);

        vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
        LoanLogic.borrow(lendingPool, USDbC, borrowAmountAboveMax);
    }

    /// @dev test confirming that we can withdraw `maxWithdrawAmount` returned from loan state
    function test_withdraw_maxWithdraw() public {
        uint256 wethAmountBefore = WETH.balanceOf(address(this));
        uint256 supplyAmount = 10 ether;
        uint256 borrowAmount = 1000 * ONE_USDbC;
        LoanLogic.supply(lendingPool, WETH, supplyAmount);
        LoanState memory loanState;
        loanState = LoanLogic.borrow(lendingPool, USDbC, borrowAmount);

        uint256 initialMaxWothdrawUSD = loanState.maxWithdrawAmount;

        // converting loanState.maxWithdrawAmount (USD) amount to the WETH asset amount
        uint256 withdrawAmount =
            Math.mulDiv(loanState.maxWithdrawAmount, 1 ether, WETH_price);
        loanState = LoanLogic.withdraw(lendingPool, WETH, withdrawAmount);

        // getting 0.01% of initial maxWithdrawUSD, because we left that as a saftey for precision issues
        uint256 maxWithdrawLeft = PercentageMath.percentMul(
            initialMaxWothdrawUSD, 1e4 - LoanLogic.MAX_AMOUNT_PERCENT
        );
        assertApproxEqAbs(
            loanState.maxBorrowAmount, 0, maxWithdrawLeft + USD_DELTA
        );

        _validateLoanState(
            loanState, supplyAmount - withdrawAmount, borrowAmount
        );
        assertApproxEqAbs(
            WETH.balanceOf(address(this)),
            wethAmountBefore - supplyAmount + withdrawAmount,
            1 wei
        );
        assertApproxEqAbs(
            sWETH.balanceOf(address(this)), supplyAmount - withdrawAmount, 1 wei
        );
    }

    /// @dev test reverting when withdraw 0.1% above `maxWithdrawAmount` returned from loan state
    function test_withdraw_maxWithdraw_revertAboveMax() public {
        uint256 supplyAmount = 10 ether;
        uint256 borrowAmount = 1000 * ONE_USDbC;
        LoanLogic.supply(lendingPool, WETH, supplyAmount);
        LoanState memory loanState;
        loanState = LoanLogic.borrow(lendingPool, USDbC, borrowAmount);

        uint256 withdrawAmount =
            Math.mulDiv(loanState.maxWithdrawAmount, 1 ether, WETH_price);
        // calculating 0.1% above max value
        uint256 withdrawAmountAboveMax =
            withdrawAmount + PercentageMath.percentMul(withdrawAmount, 10);

        vm.expectRevert();
        LoanLogic.withdraw(lendingPool, WETH, withdrawAmountAboveMax);
    }

    /// @dev fuzz test borrow, should revert if borrowing more then maxBorrowAmount
    function testFuzz_borrow(uint256 borrowAmount) public {
        vm.assume(borrowAmount > 0);

        uint256 supplyAmount = 10 ether;
        LoanState memory loanState;
        loanState = LoanLogic.supply(lendingPool, WETH, supplyAmount);

        // converting loanState.maxBorrowAmount (USD) amount to the USDbC asset amount
        uint256 maxBorrowAmountUSDbC =
            Math.mulDiv(loanState.maxBorrowAmount, ONE_USDbC, USDbC_price);

        if (borrowAmount < maxBorrowAmountUSDbC) {
            loanState = LoanLogic.borrow(lendingPool, USDbC, borrowAmount);
            _validateLoanState(loanState, supplyAmount, borrowAmount);
            assertEq(debtUSDbC.balanceOf(address(this)), borrowAmount);
        } else {
            vm.expectRevert();
            LoanLogic.borrow(lendingPool, USDbC, borrowAmount);
        }
    }

    /// @dev fuzz test borrowing & withdraw, should revert if withdraw more then maxWithdrawAmount
    function testFuzz_borrow_withdraw(
        uint256 borrowAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(withdrawAmount > 0);
        vm.assume(borrowAmount > 0);

        uint256 supplyAmount = 10 ether;
        LoanState memory loanState;
        loanState = LoanLogic.supply(lendingPool, WETH, supplyAmount);
        // converting loanState.maxBorrowAmount (USD) amount to the USDbC asset amount
        uint256 maxBorrowAmountUSDbC =
            Math.mulDiv(loanState.maxBorrowAmount, ONE_USDbC, USDbC_price);

        borrowAmount = bound(borrowAmount, ONE_USDbC, maxBorrowAmountUSDbC - 1);

        // vm.assume(borrowAmount < maxBorrowAmountUSDbC);
        loanState = LoanLogic.borrow(lendingPool, USDbC, borrowAmount);

        // converting loanState.maxWithdrawAmount (USD) amount to the CbETH asset amount
        uint256 maxWithdrawAmountCbETH =
            Math.mulDiv(loanState.maxWithdrawAmount, 1 ether, WETH_price);

        withdrawAmount =
            bound(withdrawAmount, 1000 wei, 2 * maxWithdrawAmountCbETH);

        if (withdrawAmount < maxWithdrawAmountCbETH) {
            loanState = LoanLogic.withdraw(lendingPool, WETH, withdrawAmount);
            _validateLoanState(
                loanState, supplyAmount - withdrawAmount, borrowAmount
            );
            assertApproxEqAbs(
                sWETH.balanceOf(address(this)),
                supplyAmount - withdrawAmount,
                1 wei
            );
        } else {
            vm.expectRevert();
            LoanLogic.withdraw(lendingPool, WETH, withdrawAmount);
        }
    }

    /// @dev validates if the returned LoanState values correspond for the given asset amounts
    function _validateLoanState(
        LoanState memory loanState,
        uint256 collateralWETHAmount,
        uint256 debtUSDbCAmount
    ) internal {
        // we should get value with same number of decimals as price
        // so we divide by the decimals of the asset
        uint256 collateralUSD =
            Math.mulDiv(collateralWETHAmount, WETH_price, 1 ether);
        assertApproxEqAbs(loanState.collateralUSD, collateralUSD, 1 wei);

        uint256 debtUSD = Math.mulDiv(debtUSDbCAmount, USDbC_price, ONE_USDbC);
        assertApproxEqAbs(loanState.debtUSD, debtUSD, USD_DELTA);

        uint256 maxBorrowUSD = PercentageMath.percentMul(collateralUSD, ltvWETH);
        uint256 maxAvailableBorrow = maxBorrowUSD - debtUSD;
        maxAvailableBorrow = PercentageMath.percentMul(
            maxAvailableBorrow, LoanLogic.MAX_AMOUNT_PERCENT
        );
        assertApproxEqAbs(
            loanState.maxBorrowAmount, maxAvailableBorrow, USD_DELTA
        );

        uint256 minCollateralUSD = PercentageMath.percentDiv(debtUSD, ltvWETH);
        uint256 maxAvailableWithdraw = collateralUSD - minCollateralUSD;
        maxAvailableWithdraw = PercentageMath.percentMul(
            maxAvailableWithdraw, LoanLogic.MAX_AMOUNT_PERCENT
        );
        assertApproxEqAbs(
            loanState.maxWithdrawAmount, maxAvailableWithdraw, USD_DELTA
        );
    }
}
