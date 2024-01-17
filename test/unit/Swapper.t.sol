// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IAccessControl } from
    "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { BaseForkTest } from "../BaseForkTest.t.sol";
import { SwapAdapterMock } from "../mock/SwapAdapterMock.t.sol";
import { ISwapAdapter } from "../../src/interfaces/ISwapAdapter.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { Step } from "../../src/types/DataTypes.sol";
import { Swapper } from "../../src/swap/Swapper.sol";

/// @notice Unit tests for the Swapper contract
/// @dev assuming that `BASE_MAINNET_RPC_URL` is set in the `.env`
contract SwapperTest is BaseForkTest {
    ///////////////////////////////////
    //////// REPLICATED EVENTS ////////
    ///////////////////////////////////

    /// @notice emitted when a route is set for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param steps array of Step structs needed to perform swap
    event RouteSet(IERC20 indexed from, IERC20 indexed to, Step[] steps);

    /// @notice emitted when the offsetFactor of a route is set for a given swap
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    /// @param offsetUSD offsetFactor from 0 - 1e8
    event OffsetFactorSet(
        IERC20 indexed from, IERC20 indexed to, uint256 offsetUSD
    );

    /// @notice emitted when the oracle for a given token is set
    /// @param oracle address of PriceOracleGetter contract
    event OracleSet(IPriceOracleGetter oracle);

    /// @notice emitted when a new value for the allowed deviation from the offsetFactor
    /// is set
    event OffsetDeviationSet(uint256 offsetDeviationUSD);

    /// @notice emitted when a route is removed
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    event RouteRemoved(IERC20 indexed from, IERC20 indexed to);

    /// @notice emitted when a strategy is added to strategies enumerable set
    /// @param strategy address of added strategy
    event StrategyAdded(address strategy);

    /// @notice emitted when a strategy is removed from strategies enumerable set
    /// @param strategy address of added strategy
    event StrategyRemoved(address strategy);

    IPoolAddressesProvider public constant poolAddressProvider =
        IPoolAddressesProvider(SEAMLESS_ADDRESS_PROVIDER_BASE_MAINNET);

    Swapper swapper;
    ISwapAdapter wethCbETHAdapter;
    ISwapAdapter CbETHUSDbCAdapter;

    IERC20 public constant WETH = IERC20(BASE_MAINNET_WETH);
    IERC20 public constant USDbC = IERC20(BASE_MAINNET_USDbC);
    IERC20 public constant CbETH = IERC20(BASE_MAINNET_CbETH);

    address public OWNER = makeAddr("OWNER");
    address public NO_ROLE = makeAddr("NO_ROLE");
    address public ALICE = makeAddr("ALICE");

    /// @dev sets up context for testing swapper contract
    function setUp() public {
        // deploy two mock swap adapters
        wethCbETHAdapter = new SwapAdapterMock();
        CbETHUSDbCAdapter = new SwapAdapterMock();

        // deploy and initiliaze swapper
        Swapper swapperImplementation = new Swapper();
        ERC1967Proxy swapperProxy = new ERC1967Proxy(
            address(swapperImplementation),
            abi.encodeWithSelector(
                Swapper.Swapper_init.selector, 
                OWNER
            )
        );

        swapper = Swapper(address(swapperProxy));

        vm.startPrank(OWNER);
        swapper.grantRole(swapper.MANAGER_ROLE(), OWNER);
        swapper.grantRole(swapper.UPGRADER_ROLE(), OWNER);
        swapper.setOracle(
            IPriceOracleGetter(poolAddressProvider.getPriceOracle())
        );
        vm.stopPrank();

        // fake minting some tokens to start with
        deal(address(WETH), address(this), 100 ether);
    }

    /// @dev ensures Swapper contract may be upgraded by address with UPGRADER role
    function test_upgrade() public {
        address newSwapperImplementation = address(new Swapper());
        vm.prank(OWNER);
        swapper.upgradeToAndCall(newSwapperImplementation, "");

        // slot given by OZ ECR1967 proxy implementation
        bytes32 slot = bytes32(
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        );
        address implementation =
            address(uint160(uint256(vm.load(address(swapper), slot))));

        assertEq(implementation, newSwapperImplementation);
    }

    /// @dev ensures upgrade call reverts if caller does not have UPGRADER role
    function test_ugprade_revertsWhen_calledByNonUpgrader() public {
        address newSwapperImplementation = address(new Swapper());

        vm.startPrank(NO_ROLE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                swapper.UPGRADER_ROLE()
            )
        );
        swapper.upgradeToAndCall(newSwapperImplementation, "");
        vm.stopPrank();
    }

    /// @dev ensures that a new route is set
    function test_setRoute_setsNewRoute() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.expectEmit();
        emit RouteSet(WETH, USDbC, steps);

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        Step[] memory actualSteps = swapper.getRoute(WETH, USDbC);

        for (uint256 i; i < actualSteps.length; ++i) {
            assert(address(steps[i].from) == address(actualSteps[i].from));
            assert(address(steps[i].to) == address(actualSteps[i].to));
            assert(address(steps[i].adapter) == address(actualSteps[i].adapter));
        }
    }

    /// @dev checks that the `RouteRemoved` event is emitted prior to setting a
    /// route which previously had been set, to ensure the route was removed
    /// before setting the new one
    function test_setRoute_removesOldRoutePriorToSettingNewRoute() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        vm.expectEmit();
        emit RouteRemoved(WETH, USDbC);

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);
    }

    /// @dev ensures reversion when an adapter address is the zero-address
    function test_setRoute_revertsWhen_adapterIsZeroAddress() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] =
            Step({ from: CbETH, to: USDbC, adapter: ISwapAdapter(address(0)) });

        vm.expectRevert(ISwapper.InvalidAddress.selector);

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);
    }

    /// @dev ensures setRoute reverts when called by address without MANAGER role
    function test_setRoute_revertsWhen_calledByNonManager() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] =
            Step({ from: CbETH, to: USDbC, adapter: ISwapAdapter(address(0)) });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NO_ROLE);
        swapper.setRoute(WETH, USDbC, steps);
    }

    /// @dev ensures that an existing route is removed
    function test_removeRoute_removesExistingRoute() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        vm.expectEmit();
        emit RouteRemoved(WETH, USDbC);

        vm.prank(OWNER);
        swapper.removeRoute(WETH, USDbC);

        Step[] memory routeSteps = swapper.getRoute(WETH, USDbC);

        assertEq(routeSteps.length, 0);
    }

    /// @dev ensures call is reverts if caller is not owner
    function test_removeRoute_revertsWhen_callerIsNotOwner() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.prank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NO_ROLE);
        swapper.removeRoute(WETH, USDbC);
    }

    /// @dev ensures that a new offsetFactor is set
    function test_setOffsetFactor_setsNewOffsetFactor() public {
        uint256 newOffsetFactor = 1e7;

        vm.expectEmit();
        emit OffsetFactorSet(WETH, USDbC, newOffsetFactor);

        vm.prank(OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);

        uint256 actualOffsetFactor = swapper.offsetFactor(WETH, USDbC);

        assertEq(newOffsetFactor, actualOffsetFactor);
    }

    /// @dev ensures call reverts when the new offsetFactor is outside the range
    function test_setOffsetFactor_revertsWhen_NewOffsetFactorIsOutsideRange()
        public
    {
        uint256 newOffsetFactor = 1 ether;

        vm.expectRevert(ISwapper.USDValueOutsideRange.selector);

        vm.prank(OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);

        newOffsetFactor = 0;

        vm.expectRevert(ISwapper.USDValueOutsideRange.selector);

        vm.prank(OWNER);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);
    }

    /// @dev ensures call reverts when called by non-owner
    function test_setOffsetFactor_revertsWhen_calledByNonManager() public {
        uint256 newOffsetFactor = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NO_ROLE);
        swapper.setOffsetFactor(WETH, USDbC, newOffsetFactor);
    }

    /// @dev ensures a new oracle address is set and the appropriate event is emitted
    function test_setOracle_setsNewOracle_and_emitsOracleSetEvent() public {
        assertEq(
            address(swapper.getOracle()), poolAddressProvider.getPriceOracle()
        );

        IPriceOracleGetter newOracle = IPriceOracleGetter(OWNER);
        vm.expectEmit();
        emit OracleSet(newOracle);

        vm.startPrank(OWNER);
        swapper.setOracle(newOracle);
        vm.stopPrank();

        assertEq(address(swapper.getOracle()), OWNER);
    }

    /// @dev ensures setOracle call reverts when called by non manager
    function test_setOracle_revertsWhen_calledByNonManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NO_ROLE);
        swapper.setOracle(IPriceOracleGetter(NO_ROLE));
    }

    /// @dev ensures setOffsetDeviationUSD sets new value for offsetDeviationUSD and emits appropirate event
    function test_setOffsetDeviationUSD_setsNewValueForOffsetDeviationUSD_and_emitsOffsetDeviationSetEvent(
    ) public {
        uint256 newOffsetDeviationUSD = 100;

        assertEq(0, swapper.getOffsetDeviationUSD());

        vm.expectEmit();
        emit OffsetDeviationSet(newOffsetDeviationUSD);

        vm.startPrank(OWNER);
        swapper.setOffsetDeviationUSD(newOffsetDeviationUSD);
        vm.stopPrank();

        assertEq(newOffsetDeviationUSD, swapper.getOffsetDeviationUSD());
    }

    /// @dev ensures setOffsetDeviationUSD call reverts when new offsetDeviationUSD value is larger
    /// than one USD
    function test_setOffsetDeviationUSD_revertsWhen_newValueIsLargerThanOneUSD()
        public
    {
        vm.expectRevert(ISwapper.USDValueOutsideRange.selector);

        vm.prank(OWNER);
        swapper.setOffsetDeviationUSD(type(uint256).max);
    }

    /// @dev ensures setOffsetDeviationUSD vall reverts when called by non-manager
    function test_setOffsetDeviationUSD_revertsWhen_calledByNonManager()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NO_ROLE,
                swapper.MANAGER_ROLE()
            )
        );

        vm.prank(NO_ROLE);
        swapper.setOffsetDeviationUSD(123);
    }

    /// @dev ensures swapping works for a route with a single step
    function test_swap_performsSwap_SingleStep() public {
        Step[] memory steps = new Step[](1);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        vm.startPrank(OWNER);
        swapper.setRoute(WETH, CbETH, steps);
        swapper.grantRole(swapper.STRATEGY_ROLE(), ALICE);
        vm.stopPrank();

        uint256 swapAmount = 1 ether;

        deal(address(WETH), ALICE, WETH.balanceOf(ALICE) + 10 * swapAmount);

        vm.startPrank(ALICE);
        WETH.approve(address(swapper), swapAmount);

        uint256 oldWETHBalance = WETH.balanceOf(ALICE);
        uint256 oldCbETHBalance = CbETH.balanceOf(ALICE);

        swapper.swap(WETH, CbETH, swapAmount, payable(ALICE));

        assertEq(oldWETHBalance - WETH.balanceOf(ALICE), swapAmount);
        assertEq(CbETH.balanceOf(ALICE) - oldCbETHBalance, swapAmount);
    }

    /// @dev ensures swapping works for a route with multiple steps
    function test_swap_performsSwap_MultipleSteps() public {
        Step[] memory steps = new Step[](2);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        steps[1] = Step({ from: CbETH, to: USDbC, adapter: CbETHUSDbCAdapter });

        vm.startPrank(OWNER);
        swapper.setRoute(WETH, USDbC, steps);
        swapper.grantRole(swapper.STRATEGY_ROLE(), ALICE);
        vm.stopPrank();

        uint256 swapAmount = 1 ether;

        deal(address(WETH), ALICE, WETH.balanceOf(ALICE) + 10 * swapAmount);

        vm.startPrank(ALICE);
        WETH.approve(address(swapper), swapAmount);

        uint256 oldWETHBalance = WETH.balanceOf(ALICE);
        uint256 oldUSDbCBalance = USDbC.balanceOf(ALICE);

        swapper.swap(WETH, USDbC, swapAmount, payable(ALICE));

        assertEq(oldWETHBalance - WETH.balanceOf(ALICE), swapAmount);
        assertEq(USDbC.balanceOf(ALICE) - oldUSDbCBalance, swapAmount);
    }

    /// @dev ensures swapping reverts when called by address without STRATEGY role
    function test_swap_revertsWhen_callerIsNotStrategy() public {
        Step[] memory steps = new Step[](1);

        steps[0] = Step({ from: WETH, to: CbETH, adapter: wethCbETHAdapter });

        vm.startPrank(OWNER);
        swapper.setRoute(WETH, CbETH, steps);
        vm.stopPrank();

        uint256 swapAmount = 1 ether;

        deal(address(WETH), ALICE, WETH.balanceOf(ALICE) + 10 * swapAmount);

        vm.startPrank(ALICE);
        WETH.approve(address(swapper), swapAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                swapper.STRATEGY_ROLE()
            )
        );

        swapper.swap(WETH, CbETH, swapAmount, payable(ALICE));
        vm.stopPrank();
    }
}
