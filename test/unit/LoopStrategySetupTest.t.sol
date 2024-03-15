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
import { IPoolConfigurator } from
    "@aave/contracts/interfaces/IPoolConfigurator.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IAccessControl } from
    "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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
import { WrappedERC20PermissionedDeposit } from
    "../../src/tokens/WrappedERC20PermissionedDeposit.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { IPausable } from "../../src/interfaces/IPausable.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "./LoopStrategy.t.sol";

/// @notice Setup for the tests for the LoopStrategy contract
contract LoopStrategySetupTest is LoopStrategyTest {
    using stdStorage for StdStorage;

    /// @dev ensures the address of the new implementation is the value returned from
    /// looking up the storage slot of the ERC1967 proxy implementation storage
    function test_upgrade() public {
        address newImplementation = address(new LoopStrategy());
        strategy.upgradeToAndCall(
            address(newImplementation), abi.encodePacked()
        );

        // slot given by OZ ECR1967 proxy implementation
        bytes32 slot = bytes32(
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        );
        address implementation =
            address(uint160(uint256(vm.load(address(strategy), slot))));

        assertEq(implementation, newImplementation);
    }

    /// @dev ensures that `upgradeToAndCall` role fails if caller does not have
    /// the upgrader role
    function test_upgradeToAndCall_revertsWhen_callerDoesNotHaveUpgraderRole()
        public
    {
        address newImplementation = address(new LoopStrategy());

        vm.startPrank(NO_ROLE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.UPGRADER_ROLE()
            )
        );
        strategy.upgradeToAndCall(
            address(newImplementation), abi.encodePacked()
        );
        vm.stopPrank();
    }

    /// @dev test confirms that functions reverts when pool is paused
    function test_pausableFunctions_revertEnforcedPause() public {
        IPausable(address(strategy)).pause();

        vm.expectRevert(
            abi.encodeWithSelector(IPausable.EnforcedPause.selector)
        );
        strategy.deposit(1 ether, address(this));
        vm.expectRevert(
            abi.encodeWithSelector(IPausable.EnforcedPause.selector)
        );
        strategy.withdraw(1 ether, address(this), address(this));
        vm.expectRevert(
            abi.encodeWithSelector(IPausable.EnforcedPause.selector)
        );
        strategy.redeem(1 ether, address(this), address(this));
    }

    /// @dev ensures pause call reverts if caller does not have pauser role
    function test_pause_revertsWhen_callerIsNotPauser() public {
        vm.startPrank(NO_ROLE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.PAUSER_ROLE()
            )
        );

        IPausable(address(strategy)).pause();
        vm.stopPrank();
    }

    /// @dev ensures setInterestRateMode sets new interest rate mode
    function test_setInterestRateMode_setsNewInterestRateMode() public {
        uint256 newInterestRateMode = 100;

        strategy.setInterestRateMode(newInterestRateMode);

        // slot found from LoopStrategy storage lib
        uint256 interestRateMode = uint256(
            vm.load(
                address(strategy),
                bytes32(
                    uint256(
                        0x324C4071AA3926AF75895CE4C01A62A23C8476ED82CD28BA23ABB8C0F6634B00
                    ) + 12
                )
            )
        );

        assertEq(interestRateMode, newInterestRateMode);
    }

    /// @dev ensures setInterestRateMode reverts if caller does not have manager role
    function test_setInterestRateMode_revertsWhen_callerIsNotManager() public {
        vm.startPrank(NO_ROLE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.MANAGER_ROLE()
            )
        );

        strategy.setInterestRateMode(1);
        vm.stopPrank();
    }

    /// @dev ensures setCollateralRaioTargets sets new values for the collateralRatiotargets
    function test_setCollateralRatioTargets_setsNewCollateralRatioTargets()
        public
    {
        CollateralRatio memory newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(180, 200),
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.expectEmit();
        emit CollateralRatioTargetsSet(newCollateralRatioTargets);

        strategy.setCollateralRatioTargets(newCollateralRatioTargets);

        CollateralRatio memory strategyTargets =
            strategy.getCollateralRatioTargets();

        assertEq(newCollateralRatioTargets.target, strategyTargets.target);

        assertEq(
            newCollateralRatioTargets.minForRebalance,
            strategyTargets.minForRebalance
        );

        assertEq(
            newCollateralRatioTargets.maxForRebalance,
            strategyTargets.maxForRebalance
        );

        assertEq(
            newCollateralRatioTargets.maxForDepositRebalance,
            strategyTargets.maxForDepositRebalance
        );

        assertEq(
            newCollateralRatioTargets.minForWithdrawRebalance,
            strategyTargets.minForWithdrawRebalance
        );
    }

    /// @dev ensures setCollateralRatioTargets reverts when the new target values are not logically
    /// consistent
    function test_setCollateralRatioTargets_revertsWhen_newCollateralRatioTargetsAreInvalid(
    ) public {
        // minForWithdrawRebalance > target
        CollateralRatio memory newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(180, 200),
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(201, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        strategy.setCollateralRatioTargets(newCollateralRatioTargets);

        //maxForDepositRebalance < target
        newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(200, 200),
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(199, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        strategy.setCollateralRatioTargets(newCollateralRatioTargets);

        //minForWithdrawRebalance < minForRebalance
        newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(180, 200),
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(179, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        strategy.setCollateralRatioTargets(newCollateralRatioTargets);

        //maxForDepositRebalance < maxForRebalance
        newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(180, 200),
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(230, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        strategy.setCollateralRatioTargets(newCollateralRatioTargets);

        //minForRebalance = 0
        newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: 0,
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        strategy.setCollateralRatioTargets(newCollateralRatioTargets);

        //maxForRebalance = type(uint256).max
        newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(180, 200),
            maxForRebalance: type(uint256).max,
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        strategy.setCollateralRatioTargets(newCollateralRatioTargets);
    }

    /// @dev ensures setCollateralRaioTargets reverts if caller is not manager
    function test_setCollateralRatioTargets_revertsWhen_callerIsNotManager()
        public
    {
        CollateralRatio memory newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: USDWadRayMath.usdDiv(180, 200),
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.startPrank(NO_ROLE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.MANAGER_ROLE()
            )
        );

        strategy.setCollateralRatioTargets(newCollateralRatioTargets);
        vm.stopPrank();
    }

    /// @dev ensures a new value for ratioMargin is set and the appropriate event is emitted
    function test_setRatioMargin_setNewValueForRatioMargin_and_emitsRatioMarginSetEvent(
    ) public {
        uint256 marginUSD = 10;

        vm.expectEmit();
        emit RatioMarginSet(marginUSD);

        strategy.setRatioMargin(marginUSD);

        assertEq(strategy.getRatioMargin(), marginUSD);
    }

    /// @dev ensures setRatioMargin call is reverted when called by non-manager
    function test_setRatioMargin_revertsWhen_callerIsNotManager() public {
        uint256 marginUSD = 10;
        vm.startPrank(NO_ROLE);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.MANAGER_ROLE()
            )
        );
        strategy.setRatioMargin(marginUSD);
    }

    /// @dev ensures setRatioMargin reverts when new value is outside range
    function test_setRatioMargin_revertsWhen_valueExceeds_1e8() public {
        uint256 marginUSD = 1e8 + 1;

        vm.expectRevert(ILoopStrategy.MarginOutsideRange.selector);

        strategy.setRatioMargin(marginUSD);
    }

    /// @dev ensures a new value for maxIterations is set and the appropriate event is emitted
    function test_setMaxIterations_setNewValueForMaxIterations_and_emitsMaxIterationsSetEvent(
    ) public {
        uint16 iterations = 10;

        vm.expectEmit();
        emit MaxIterationsSet(iterations);

        strategy.setMaxIterations(iterations);

        assertEq(strategy.getMaxIterations(), iterations);
    }

    /// @dev ensures setMaxIterations call is reverted when called by non-manager
    function test_setMaxIterations_revertsWhen_callerIsNotManager() public {
        uint16 iterations = 10;
        vm.startPrank(NO_ROLE);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.MANAGER_ROLE()
            )
        );
        strategy.setMaxIterations(iterations);
    }

    /// @dev ensures a new value for swapper is set and the appropriate event is emitted
    function test_setSwapper_setNewValueForSwapper_and_emitsSwapperSetEvent()
        public
    {
        vm.expectEmit();
        emit SwapperSet(alice);

        strategy.setSwapper(alice);

        assertEq(strategy.getSwapper(), alice);
    }

    /// @dev ensures setSwapper call is reverted when called by non-manager
    function test_setSwapper_revertsWhen_callerIsNotManager() public {
        vm.startPrank(NO_ROLE);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.MANAGER_ROLE()
            )
        );
        strategy.setSwapper(alice);
    }

    /// @dev ensures unpause call reverts if caller does not have pauser role
    function test_unpause_revertsWhen_callerIsNotPauser() public {
        vm.startPrank(NO_ROLE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                strategy.PAUSER_ROLE()
            )
        );

        IPausable(address(strategy)).unpause();
        vm.stopPrank();
    }

    /// @dev test confimrs that mint function is disabled
    function test_mint_revertMintDisabled() public {
        vm.expectRevert(
            abi.encodeWithSelector(ILoopStrategy.MintDisabled.selector)
        );
        strategy.mint(1 ether, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(ILoopStrategy.MintDisabled.selector)
        );
        strategy.previewMint(1 ether);
    }

    /// @dev test confimrs that withdraw function is disabled
    function test_withdraw_revertsWhen_called() public {
        vm.expectRevert(
            abi.encodeWithSelector(ILoopStrategy.WithdrawDisabled.selector)
        );
        strategy.withdraw(1 ether, address(this), address(this));

        vm.expectRevert(
            abi.encodeWithSelector(ILoopStrategy.WithdrawDisabled.selector)
        );
        strategy.previewWithdraw(1 ether);
    }

    /// @dev test confirms that changing asset price on the price oracle works
    function test_changePrice() public {
        _changePrice(CbETH, 1234 * 1e8);
        assertEq(priceOracle.getAssetPrice(address(CbETH)), 1234 * 1e8);
    }

    /// @dev test confirms that initialization function validates parameters
    function test_initialization_revertsOnInvalidParameters() public {
        LoopStrategy strategyImplementation = new LoopStrategy();

        // minForRebalance = 0
        CollateralRatio memory newCollateralRatioTargets = CollateralRatio({
            target: USDWadRayMath.usdDiv(200, 200),
            minForRebalance: 0,
            maxForRebalance: USDWadRayMath.usdDiv(220, 200),
            maxForDepositRebalance: USDWadRayMath.usdDiv(203, 200),
            minForWithdrawRebalance: USDWadRayMath.usdDiv(197, 200)
        });

        vm.expectRevert(ILoopStrategy.InvalidCollateralRatioTargets.selector);
        new ERC1967Proxy(
            address(strategyImplementation),
            abi.encodeWithSelector(
                LoopStrategy.LoopStrategy_init.selector,
                "ILM_NAME",
                "ILM_SYMBOL",
                address(this),
                strategyAssets,
                newCollateralRatioTargets,
                poolAddressProvider,
                priceOracle,
                swapper,
                10 ** 4,
                10
            )
        );

        // marginUSD > 1e8
        uint256 newMarginUSD = 1e8 + 1;

        vm.expectRevert(ILoopStrategy.MarginOutsideRange.selector);
        new ERC1967Proxy(
            address(strategyImplementation),
            abi.encodeWithSelector(
                LoopStrategy.LoopStrategy_init.selector,
                "ILM_NAME",
                "ILM_SYMBOL",
                address(this),
                strategyAssets,
                collateralRatioTargets,
                poolAddressProvider,
                priceOracle,
                swapper,
                newMarginUSD,
                10
            )
        );
    }
}
