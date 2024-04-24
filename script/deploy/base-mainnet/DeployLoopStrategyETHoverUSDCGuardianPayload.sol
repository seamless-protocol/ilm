// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IAccessControl } from
    "@openzeppelin/contracts/access/IAccessControl.sol";
import { ISwapper } from "../../../src/swap/Swapper.sol";
import { ILoopStrategy } from "../../../src/LoopStrategy.sol";
import { IWrappedTokenAdapter } from
    "../../../src/interfaces/IWrappedTokenAdapter.sol";
import { IAerodromeAdapter } from
    "../../../src/interfaces/IAerodromeAdapter.sol";
import {
    IWrappedERC20PermissionedDeposit
} from "../../../src/tokens/WrappedERC20PermissionedDeposit.sol";
import { StrategyAssets
} from "../../../src/types/DataTypes.sol";
import { ISwapAdapter } from "../../../src/interfaces/ISwapAdapter.sol";
import { DeployHelperLib } from "../DeployHelperLib.sol";
import { BaseMainnetConstants } from "../config/BaseMainnetConstants.sol";

interface IOwnable2Step {
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
}

/// @notice Helper setup contract which guardian or governance can call through delegate call to setup this strategy
contract DeployLoopStrategyETHoverUSDCGuardianPayload is
    BaseMainnetConstants
{
    error NotAuthorized();

    function run(ILoopStrategy strategy, uint256 swapperOffsetFactor)
        external
    {
        if (
            msg.sender != SEAMLESS_COMMUNITY_MULTISIG
                && msg.sender != SEAMLESS_GOV_SHORT_TIMELOCK_ADDRESS
        ) {
            revert NotAuthorized();
        }

        _acceptRoles();

        StrategyAssets memory strategyAssets = strategy.getAssets();

        IWrappedERC20PermissionedDeposit wrappedToken =
            IWrappedERC20PermissionedDeposit(address(strategyAssets.collateral));
        IWrappedTokenAdapter wrappedTokenAdapter =
            IWrappedTokenAdapter(WRAPPED_TOKEN_ADAPTER);

        IAccessControl(address(wrappedToken)).grantRole(
            wrappedToken.DEPOSITOR_ROLE(), address(strategy)
        );
        IAccessControl(address(wrappedToken)).grantRole(
            wrappedToken.DEPOSITOR_ROLE(), WRAPPED_TOKEN_ADAPTER
        );

        IWrappedTokenAdapter(WRAPPED_TOKEN_ADAPTER).setWrapper(
            wrappedToken.underlying(),
            IERC20(address(wrappedToken)),
            wrappedToken
        );

        DeployHelperLib._setAerodromeAdapterRoutes(
            IAerodromeAdapter(AERODROME_ADAPTER),
            strategyAssets.underlying,
            strategyAssets.debt,
            AERODROME_FACTORY
        );

        DeployHelperLib._setSwapperRouteBetweenWrappedAndToken(
            ISwapper(SWAPPER),
            wrappedToken,
            strategyAssets.debt,
            ISwapAdapter(address(wrappedTokenAdapter)),
            ISwapAdapter(AERODROME_ADAPTER),
            swapperOffsetFactor
        );

        bytes32 STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
        IAccessControl(SWAPPER).grantRole(STRATEGY_ROLE, address(strategy));

        _renounceRoles();
    }

    function _acceptRoles() internal {
        IOwnable2Step(WRAPPED_TOKEN_ADAPTER).acceptOwnership();
        IOwnable2Step(AERODROME_ADAPTER).acceptOwnership();
    }

    function _renounceRoles() internal {
        IOwnable2Step(WRAPPED_TOKEN_ADAPTER).transferOwnership(
            SEAMLESS_COMMUNITY_MULTISIG
        );
        IOwnable2Step(AERODROME_ADAPTER).transferOwnership(
            SEAMLESS_COMMUNITY_MULTISIG
        );

        bytes32 MANAGER_ROLE = keccak256("MANAGER_ROLE");
        IAccessControl(SWAPPER).renounceRole(MANAGER_ROLE, address(this));
        IAccessControl(BASE_MAINNET_SEAMLESS_WRAPPED_WETH).renounceRole(
            MANAGER_ROLE, address(this)
        );
    }
}
