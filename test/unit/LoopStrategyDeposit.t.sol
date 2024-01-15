// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC4626Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import { BaseForkTest } from "../BaseForkTest.t.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "./LoopStrategy.t.sol";

/// @notice Unit tests for the LoopStrategy deposit flow
contract LoopStrategyDepositTest is LoopStrategyTest {
    /// @dev test confirms that initial deposit works as itended and the correct amount of shares is issued equal to the equity
    function test_deposit_firstDeposit() public {
        uint256 depositAmount = 1 ether;
        uint256 sharesReturned = _depositFor(alice, depositAmount);
        _validateCollateralRatio(collateralRatioTargets.target);

        uint256 sharesReceived = IERC20(address(strategy)).balanceOf(alice);
        assert(sharesReceived > 0);
        assertEq(sharesReceived, sharesReturned);

        uint256 shouldReceive = (
            depositAmount * (USDWadRayMath.USD - swapOffset)
        ) / USDWadRayMath.USD;

        // the biggest acceptable loss set to be 1%
        assertApproxEqRel(sharesReceived, shouldReceive, 0.01 ether);

        assertEq(strategy.totalAssets(), sharesReceived);
        assertEq(strategy.equity(), sharesReceived);
    }

    /// @dev test confirms that multiple deposit by different users works correctly
    function test_deposit_multipleDeposits() public {
        uint256 depositAlice = 0.3 ether;
        uint256 depositBob = 0.2 ether;
        uint256 depositCharlie = 0.1 ether;
        uint256 sharesAlice = _depositFor(alice, depositAlice);
        uint256 sharesBob = _depositFor(bob, depositBob);
        uint256 sharesCharlie = _depositFor(charlie, depositCharlie);

        assert(sharesAlice > sharesBob && sharesBob > sharesCharlie);
        assertEq(sharesAlice, IERC20(address(strategy)).balanceOf(alice));
        assertEq(sharesBob, IERC20(address(strategy)).balanceOf(bob));
        assertEq(sharesCharlie, IERC20(address(strategy)).balanceOf(charlie));
        assertEq(
            strategy.totalSupply(), sharesAlice + sharesBob + sharesCharlie
        );
        assertEq(strategy.totalSupply(), strategy.totalAssets());

        _validateCollateralRatio(collateralRatioTargets.maxForDepositRebalance);
    }

    /// @dev test confirms that pool rebalance is done if the current collateral ratio is out of acceptable range
    function test_deposit_shouldRebalance() public {
        uint256 depositAlice = 3 ether;
        _depositFor(alice, depositAlice);
        _validateCollateralRatio(collateralRatioTargets.target);

        // price of CbETH goes up so collateral ratio becomes bigger than maxForRebalance
        _changePrice(CbETH, 2300 * 1e8);
        assertEq(strategy.rebalanceNeeded(), true);
        uint256 depositBob = 0.2 ether;
        _depositFor(bob, depositBob);
        _validateCollateralRatio(collateralRatioTargets.maxForDepositRebalance);

        // price of CbETH goes down so collateral ratio becomes lower than minForRebalance
        _changePrice(CbETH, 2000 * 1e8);
        assertEq(strategy.rebalanceNeeded(), true);
        uint256 depositCharlie = 0.3 ether;
        _depositFor(charlie, depositCharlie);
        _validateCollateralRatio(collateralRatioTargets.maxForDepositRebalance);
    }

    /// @dev test confirms that collateral ratio is the same as it was before deposit in the case when it started above maxForDepositRebalance
    function test_deposit_returnsToTheSameCR() public {
        uint256 depositAlice = 3 ether;
        _depositFor(alice, depositAlice);
        // price of CbETH goes up so collateral ratio becomes bigger than maxForDepositRebalance
        _changePrice(CbETH, 2050 * 1e8);
        uint256 beforeCR = strategy.currentCollateralRatio();
        assert(beforeCR > collateralRatioTargets.maxForDepositRebalance);

        uint256 depositBob = 0.3 ether;
        _depositFor(bob, depositBob);
        _validateCollateralRatio(beforeCR);
    }

    /// @dev test confirms there is no rebalance if resulting collateral ratio is below maxForDepositRebalance
    /// @dev we check this by receiving equity equal to the asset value (there is no dex fee loss)
    function test_deposit_noRebalanceBelowMaxForDepositRebalance() public {
        uint256 depositAlice = 3 ether;
        _depositFor(alice, depositAlice);
        _changePrice(CbETH, 1900 * 1e8);

        uint256 depositBob = 0.2 ether;
        uint256 expectedShares = strategy.convertToShares(depositBob);
        uint256 sharesBob = _depositFor(bob, depositBob);
        assertEq(sharesBob, expectedShares);
    }

    /// @dev test reverting when deposit with minSharesReceived is used and lower shares received;
    /// @dev using setup same as noRebalanceBelowMaxForDepositRebalance because we can calculate exact number of shares
    function test_deposit_revertSharesReceivedBelowMinimum() public {
        uint256 depositAlice = 3 ether;
        _depositFor(alice, depositAlice);
        _changePrice(CbETH, 1900 * 1e8);

        uint256 depositBob = 0.2 ether;
        uint256 expectedShares = strategy.convertToShares(depositBob);
        // set min to receive to 0.01% above expected
        uint256 minSharesAboveExpexted =
            PercentageMath.percentMul(expectedShares, 10_001);

        // can't use _depositFor because of vm.expectRevert
        vm.startPrank(bob);
        deal(address(strategyAssets.underlying), bob, depositBob);
        strategyAssets.underlying.approve(address(strategy), depositBob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ILoopStrategy.SharesReceivedBelowMinimum.selector,
                expectedShares,
                minSharesAboveExpexted
            )
        );
        strategy.deposit(depositBob, bob, minSharesAboveExpexted);
        vm.stopPrank();
    }

    /// @dev test confimrs that deposit is allowed once max supply or borrow cap is reached
    function test_deposit_maxSupplyReached() public {
        uint256 depositAlice = 3 ether;
        _depositFor(alice, depositAlice);

        // borrow cap is low now so we don't have any more available USDbC on lending pool
        _changeBorrowCap(USDbC, 100_000);
        uint256 beforeCR = strategy.currentCollateralRatio();

        uint256 depositBob = 5 ether;
        uint256 expectedShares = strategy.convertToShares(depositBob);
        uint256 sharesBob = _depositFor(bob, depositBob);

        uint256 afterCR = strategy.currentCollateralRatio();
        // this is the only case when it's ok to finish with CR more than both beforeCR and maxForDepositRebalance
        assert(
            afterCR > beforeCR
                && afterCR > collateralRatioTargets.maxForDepositRebalance
        );

        // bob didn't lose on fees because there was no rebalance even though we are out of range
        assert(afterCR > collateralRatioTargets.maxForRebalance);
        assertEq(sharesBob, expectedShares);
    }

    /// @dev test confirms that preview deposit function is returning correct value with relative error max 0.001%
    function test_previewDeposit() public {
        uint256 depositAlice = 0.5 ether;
        uint256 previewShares = strategy.previewDeposit(depositAlice);
        uint256 actualShares = _depositFor(alice, depositAlice);
        assertApproxEqRel(previewShares, actualShares, 0.00001 ether);
    }

    /// @dev test confirms that maxDeposit function is returning the correct value when assetsCap is set
    function test_maxDeposit() public {
        uint256 assetsCap = 10 ether;
        strategy.setAssetsCap(assetsCap);

        assertEq(strategy.maxDeposit(alice), assetsCap);

        uint256 depositAlice = 1 ether;
        uint256 actualShares = _depositFor(alice, depositAlice);

        assertEq(strategy.maxDeposit(alice), assetsCap - actualShares);
    }

    /// @dev test confirms that deposit reverts when user tries to deposit more than current maxDeposit
    function test_deposit_revertERC4626ExceededMaxDeposit() public {
        uint256 assetsCap = 10 ether;
        strategy.setAssetsCap(assetsCap);

        uint256 depositAlice = 15 ether;
        bytes memory revertReason =
            abi.encodeWithSelector(
                ERC4626Upgradeable.ERC4626ExceededMaxDeposit.selector,
                alice,
                depositAlice,
                assetsCap
            );

        _depositForExpectsRevert(alice, depositAlice, revertReason);
    }

    /// @dev validates current collateral ratio with relative error max 0.01%
    function _validateCollateralRatio(uint256 expectedCR) internal {
        assertApproxEqRel(
            strategy.currentCollateralRatio(), expectedCR, 0.0001 ether
        );
    }
}
