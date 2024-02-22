// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ISwapper, Swapper } from "../../../src/swap/Swapper.sol";
import { LoopStrategy, ILoopStrategy } from "../../../src/LoopStrategy.sol";
import { WrappedTokenAdapter } from "../../../src/swap/adapter/WrappedTokenAdapter.sol";
import { AerodromeAdapter } from "../../../src/swap/adapter/AerodromeAdapter.sol";
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
        wrappedTokenERC20Config: ERC20Config("",""), // empty, not used
        wrappedTokenReserveConfig: ReserveConfig(address(0),"","","","","","",0,0,0), // empty, not used
        collateralRatioConfig: CollateralRatioConfig({
            collateralRatioTargets: CollateralRatio({
                target: USDWadRayMath.usdDiv(150, 50), // 1.5
                minForRebalance: USDWadRayMath.usdDiv(135, 35), // 1.35
                maxForRebalance: USDWadRayMath.usdDiv(1500015, 500015), // 1.500015
                maxForDepositRebalance: USDWadRayMath.usdDiv(150, 50), // 1.5
                minForWithdrawRebalance: USDWadRayMath.usdDiv(150, 50) // 1.5
             }),
            ratioMargin: 1, // 0.000001% ratio margin
            maxIterations: 10
        }),
        swapperConfig: SwapperConfig({
            swapperOffsetFactor: 350000, // 0.35 %
            swapperOffsetDeviation: 100000000 // 100%
         })
    });
}

contract DeployLoopStrategyWstETHoverETH is Script, DeployHelper, LoopStrategyWstETHoverETHConfig {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        Swapper swapper = _deploySwapper(
            deployerAddress, wstETHoverETHconfig.swapperConfig.swapperOffsetDeviation
        );

        (WrappedTokenAdapter wrappedTokenAdapter, AerodromeAdapter aerodromeAdapter) = _deploySwapAdapters(
            Swapper(address(swapper)), wrappedToken, deployerAddress
        );

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

        _setupSwapperRoles(Swapper(address(swapper)), strategy);

        // set admin roles on swapper
        swapper.grantRole(wrappedToken.DEFAULT_ADMIN_ROLE(), SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS);
        swapper.grantRole(wrappedToken.DEFAULT_ADMIN_ROLE(), SEAMLESS_COMMUNITY_MULTISIG);

        // set admin roles on strategy
        strategy.grantRole(wrappedToken.DEFAULT_ADMIN_ROLE(), SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS);
        strategy.grantRole(wrappedToken.DEFAULT_ADMIN_ROLE(), SEAMLESS_COMMUNITY_MULTISIG);

        // transfer ownership on token adapters
        wrappedTokenAdapter.transferOwnership(SEAMLESS_COMMUNITY_MULTISIG);
        aerodromeAdapter.transferOwnership(SEAMLESS_COMMUNITY_MULTISIG);

        // renounce deployer admin roles
        swapper.renounceRole(wrappedToken.DEFAULT_ADMIN_ROLE(), deployerAddress);
        strategy.renounceRole(wrappedToken.DEFAULT_ADMIN_ROLE(), deployerAddress);


        vm.stopBroadcast();
    }
}

// After deploy SEAMLESS_COMMUNITY_MULTISIG should execute:
    // wrappedToken.grantRole(wrappedToken.DEPOSITOR_ROLE(), strategy);
    // wrappedToken.grantRole(
    //     wrappedToken.DEPOSITOR_ROLE(), wrappedTokenAdapter
    // );
    // wrappedTokenAdapter.acceptOwnership()
    // aerodromeAdapter.acceptOwnership()