// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IAccessControl } from
    "@openzeppelin/contracts/access/IAccessControl.sol";
import { ISwapper, Swapper } from "../../../src/swap/Swapper.sol";
import { LoopStrategy, ILoopStrategy } from "../../../src/LoopStrategy.sol";
import { WrappedTokenAdapter } from
    "../../../src/swap/adapter/WrappedTokenAdapter.sol";
import { AerodromeAdapter } from
    "../../../src/swap/adapter/AerodromeAdapter.sol";
import { DeployHelper } from "../DeployHelper.s.sol";
import { WrappedERC20PermissionedDeposit } from
    "../../../src/tokens/WrappedERC20PermissionedDeposit.sol";
import {
    LoopStrategyConfig,
    ERC20Config,
    ReserveConfig,
    CollateralRatioConfig,
    SwapperConfig
} from "../config/LoopStrategyConfig.sol";
import { CollateralRatio } from "../../../src/types/DataTypes.sol";
import { USDWadRayMath } from "../../../src/libraries/math/USDWadRayMath.sol";
import { BaseMainnetConstants } from "../config/BaseMainnetConstants.sol";

contract LoopStrategyWstETHoverETHConfig is BaseMainnetConstants {
    WrappedERC20PermissionedDeposit public wrappedToken =
    WrappedERC20PermissionedDeposit(0xc9ae3B5673341859D3aC55941D27C8Be4698C9e4);

    uint256 public assetsCap = 35 ether;

    LoopStrategyConfig public wstETHoverETHconfig = LoopStrategyConfig({
        // wstETH address
        underlyingTokenAddress: BASE_MAINNET_wstETH,
        // wstETH-USD Adapter oracle (used in the Seamless pool)
        underlyingTokenOracle: 0xD815218fA8c9bd605c2b048f26cd374A752cAA76,
        strategyERC20Config: ERC20Config({
            name: "Seamless ILM 3x Loop wstETH/ETH",
            symbol: "ilm-wstETH/ETH-3xloop"
        }),
        wrappedTokenERC20Config: ERC20Config("", ""), // empty, not used
        wrappedTokenReserveConfig: ReserveConfig(
            address(0), "", "", "", "", "", "", 0, 0, 0
        ), // empty, not used
        collateralRatioConfig: CollateralRatioConfig({
            collateralRatioTargets: CollateralRatio({
                target: USDWadRayMath.usdDiv(150, 100), // 1.5
                minForRebalance: USDWadRayMath.usdDiv(135, 100), // 1.35
                maxForRebalance: USDWadRayMath.usdDiv(1500015, 1000000), // 1.500015
                maxForDepositRebalance: USDWadRayMath.usdDiv(150, 100), // 1.5
                minForWithdrawRebalance: USDWadRayMath.usdDiv(150, 100) // 1.5
             }),
            ratioMargin: 1, // 0.000001% ratio margin
            maxIterations: 20
        }),
        swapperConfig: SwapperConfig({
            swapperOffsetFactor: 350000, // 0.35 %
            swapperOffsetDeviation: 200000000 // 200%
         })
    });
}

contract DeployLoopStrategyWstETHoverETH is
    Script,
    DeployHelper,
    LoopStrategyWstETHoverETHConfig
{
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        Swapper swapper = _deploySwapper(
            deployerAddress,
            wstETHoverETHconfig.swapperConfig.swapperOffsetDeviation
        );

        (
            WrappedTokenAdapter wrappedTokenAdapter,
            AerodromeAdapter aerodromeAdapter
        ) = _deploySwapAdapters(swapper, wrappedToken, deployerAddress);

        _setupSwapperRoutes(
            Swapper(address(swapper)),
            wrappedToken,
            wrappedTokenAdapter,
            aerodromeAdapter,
            wstETHoverETHconfig.swapperConfig.swapperOffsetFactor
        );

        LoopStrategy strategy = _deployLoopStrategy(
            wrappedToken, deployerAddress, swapper, wstETHoverETHconfig
        );

        strategy.setAssetsCap(assetsCap);

        _setupSwapperRoles(swapper, strategy);

        // set roles on swapper
        _grantRoles(swapper, swapper.DEFAULT_ADMIN_ROLE());
        _grantRoles(swapper, swapper.MANAGER_ROLE());
        _grantRoles(swapper, swapper.UPGRADER_ROLE());

        // set roles on strategy
        _grantRoles(strategy, strategy.DEFAULT_ADMIN_ROLE());
        _grantRoles(strategy, strategy.MANAGER_ROLE());
        _grantRoles(strategy, strategy.UPGRADER_ROLE());
        _grantRoles(strategy, strategy.PAUSER_ROLE());

        // transfer ownership on token adapters
        wrappedTokenAdapter.transferOwnership(SEAMLESS_COMMUNITY_MULTISIG);
        aerodromeAdapter.transferOwnership(SEAMLESS_COMMUNITY_MULTISIG);

        // renounce deployer roles
        swapper.renounceRole(swapper.MANAGER_ROLE(), deployerAddress);
        swapper.renounceRole(swapper.UPGRADER_ROLE(), deployerAddress);
        swapper.renounceRole(swapper.DEFAULT_ADMIN_ROLE(), deployerAddress);

        strategy.renounceRole(strategy.MANAGER_ROLE(), deployerAddress);
        strategy.renounceRole(strategy.PAUSER_ROLE(), deployerAddress);
        strategy.renounceRole(strategy.UPGRADER_ROLE(), deployerAddress);
        strategy.renounceRole(strategy.DEFAULT_ADMIN_ROLE(), deployerAddress);

        vm.stopBroadcast();
    }

    function _grantRoles(IAccessControl accessContract, bytes32 role)
        internal
    {
        accessContract.grantRole(role, SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS);
        accessContract.grantRole(role, SEAMLESS_COMMUNITY_MULTISIG);
    }
}
